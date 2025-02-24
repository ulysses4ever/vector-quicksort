-- |
-- Module:     Data.Vector.Algorithms.Quicksort.Parameterised
-- Copyright:  (c) Sergey Vinokurov 2023
-- License:    Apache-2.0 (see LICENSE)
-- Maintainer: serg.foo@gmail.com
--
-- This module provides fully generic quicksort for now allowing
-- caller to decide how to parallelize and how to select median. More
-- things may be parameterised in the future, likely by introducing
-- new functions taking more arguments.
--
-- === Example
-- This is how you’d define parallel sort that uses sparks on unboxed vectors of integers:
--
-- >>> import Control.Monad.ST
-- >>> import Data.Int
-- >>> import Data.Vector.Algorithms.Quicksort.Parameterised
-- >>> import Data.Vector.Unboxed qualified as U
-- >>> :{
-- let myParallelSort :: U.MVector s Int64 -> ST s ()
--     myParallelSort = sortInplaceFM defaultParStrategies (Median3or5 @Int64)
-- in U.modify myParallelSort $ U.fromList @Int64 [20, 19 .. 0]
-- :}
-- [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
--
-- === Design considerations
-- Because of reliance on specialisation, this package doesn't provide
-- sort functions that take comparator function as argument. They rely
-- on the 'Ord' instance instead. While somewhat limiting, this allows
-- to offload optimization to the @SPECIALIZE@ pragmas even if compiler
-- wasn't smart enough to monomorphise automatically.
--
-- === Performance considerations
-- Compared to the default sort this one is even more sensitive to
-- specialisation. Users caring about performance are advised to dump
-- core and ensure that sort is monomorphised. The GHC 9.6.1 was seen
-- to specialize automatically but 9.4 wasn't as good and required
-- pragmas both for the main sort function and for its helpers, like this:
--
-- > -- Either use the flag to specialize everything, ...
-- > {-# OPTIONS_GHC -fspecialise-aggressively #-}
-- >
-- > -- ... or the pragmas for specific functions
-- > import Control.Monad.ST
-- > import Data.Int
-- > import Data.Vector.Algorithms.FixedSort
-- > import Data.Vector.Algorithms.Heapsort
-- > import Data.Vector.Algorithms.Quicksort.Parameterised
-- > import Data.Vector.Unboxed qualified as U
-- >
-- > {-# SPECIALIZE heapSort      :: U.MVector s Int64 -> ST s ()        #-}
-- > {-# SPECIALIZE bitonicSort   :: Int -> U.MVector s Int64 -> ST s () #-}
-- > {-# SPECIALIZE sortInplaceFM :: Sequential -> Median3 Int64 -> U.MVector s Int64 -> ST s () #-}
--
-- === Speeding up compilation
-- In order to speed up compilations it's a good idea to introduce
-- dedicated module where all the sorts will reside and import it
-- instead of calling @sort@ or @sortInplaceFM@ in moduler with other logic.
-- This way the sort functions, which can take a while to compile, will be
-- recompiled rarely.
--
-- > module MySorts (mySequentialSort) where
-- >
-- > import Control.Monad.ST
-- > import Data.Int
-- > import Data.Vector.Unboxed qualified as U
-- >
-- > import Data.Vector.Algorithms.Quicksort.Parameterised
-- >
-- > {-# NOINLINE mySequentialSort #-}
-- > mySequentialSort :: U.MVector s Int64 -> ST s ()
-- > mySequentialSort = sortInplaceFM Sequential (Median3or5 @Int64)
--
-- === Reducing code bloat
-- Avoid using sorts with both 'ST' and 'IO' monads. Stick to the 'ST'
-- monad as much as possible because it can be easily converted to
-- 'IO' via safe 'stToIO' function. Using same sort in both 'IO' and
-- 'ST' monads will compile two versions of it along with all it’s
-- helper sorts which can be pretty big (especially the bitonic sort).

-- So that haddock will resolve references in the documentation.
{-# OPTIONS_GHC -Wno-unused-imports #-}

module Data.Vector.Algorithms.Quicksort.Parameterised
  ( sortInplaceFM
  -- * Reexports
  , module E
  ) where

import Prelude hiding (last, pi)

import Control.Monad
import Control.Monad.Primitive
import Data.Bits
import Data.Vector.Generic.Mutable qualified as GM

import Data.Vector.Algorithms.FixedSort
import Data.Vector.Algorithms.Heapsort
import Data.Vector.Algorithms.Quicksort.Fork2 as E
import Data.Vector.Algorithms.Quicksort.Median as E

-- For haddock
import Control.Monad.ST

{-# INLINABLE sortInplaceFM #-}
-- | Quicksort parameterised by median selection method and
-- parallelisation strategy.
sortInplaceFM
  :: forall p med x m a v.
     (Fork2 p x m, Median med a m (PrimState m), PrimMonad m, Ord a, GM.MVector v a)
  => p
  -> med
  -> v (PrimState m) a
  -> m ()
sortInplaceFM !p !med !vector = do
  !releaseToken <- startWork p
  -- ParStrategies requires forcing the unit, otherwise we may return
  -- while some sparks are still working.
  () <- qsortLoop 0 releaseToken vector
  pure ()
  where
    -- If we select bad median 4 times in a row then fall back to heapsort.
    !cutoffLen = GM.length vector

    !logLen = binlog2 (GM.length vector)

    !threshold = 2 * logLen

    qsortLoop :: Int -> x -> v (PrimState m) a -> m ()
    qsortLoop !depth !releaseToken !v
      | len < 17
      = bitonicSort len v *> endWork p releaseToken

      | depth == threshold || if depthDiff > 0 then len `unsafeShiftL` depthDiff > cutoffLen else False
      = heapSort v *> endWork p releaseToken

      | otherwise = do
        let !last = len - 1
            v'    = GM.unsafeSlice 0 last v
        res <- selectMedian med v'

        (!pi', !pv) <- case res of
          Guess pv -> do
            (_, !pi') <- partitionTwoWaysGuessedPivot pv last v
            pure (pi', pv)

          ExistingValue pv pi -> do
            when (pi /= last) $ do
              GM.unsafeWrite v pi =<< GM.unsafeRead v last
              GM.unsafeWrite v last pv
            (!xi, !pi') <- partitionTwoWaysPivotAtEnd pv (last - 1) v
            GM.unsafeWrite v pi' pv
            GM.unsafeWrite v last xi
            pure (pi' + 1, pv)

        !pi'' <- skipEq pv pi' v

        let !left   = GM.unsafeSlice 0 pi' v
            !right  = GM.unsafeSlice pi'' (len - pi'') v
            !depth' = depth + 1
        fork2
          p
          releaseToken
          depth
          (qsortLoop depth')
          (qsortLoop depth')
          left
          right
      where
        !len       = GM.length v
        !depthDiff = depth - logLen

{-# INLINE partitionTwoWaysGuessedPivot #-}
partitionTwoWaysGuessedPivot
  :: (PrimMonad m, Ord a, GM.MVector v a)
  => a -> Int -> v (PrimState m) a -> m (a, Int)
partitionTwoWaysGuessedPivot !pv !lastIdx !v =
  go 0 lastIdx
  where
    go !i !j = do
      !(i', xi) <- goLT i
      !(j', xj) <- goGT j
      if i' < j'
      then do
        GM.unsafeWrite v j' xi
        GM.unsafeWrite v i' xj
        go (i' + 1) (j' - 1)
      else pure (xi, i')
      where
        goLT !k = do
          if k <= j
          then do
            !x <- GM.unsafeRead v k
            if x < pv
            then goLT (k + 1)
            else pure (k, x)
          -- Be careful not to write this pv into array - pv may not exsit there.
          else pure (k, pv)
        goGT !k = do
          !x <- GM.unsafeRead v k
          if x >= pv && i < k
          then goGT (k - 1)
          else pure (k, x)

{-# INLINE partitionTwoWaysPivotAtEnd #-}
partitionTwoWaysPivotAtEnd
  :: (PrimMonad m, Ord a, GM.MVector v a)
  => a -> Int -> v (PrimState m) a -> m (a, Int)
partitionTwoWaysPivotAtEnd !pv !lastIdx !v =
  go 0 lastIdx
  where
    go !i !j = do
      !(i', xi) <- goLT i
      !(j', xj) <- goGT j
      if i' < j'
      then do
        GM.unsafeWrite v j' xi
        GM.unsafeWrite v i' xj
        go (i' + 1) (j' - 1)
      else pure (xi, i')
      where
        goLT !k = do
          !x <- GM.unsafeRead v k
          if x < pv && k <= j
          then goLT (k + 1)
          else pure (k, x)
        goGT !k = do
          !x <- GM.unsafeRead v k
          if x >= pv && i < k
          then goGT (k - 1)
          else pure (k, x)

{-# INLINE skipEq #-}
-- Idetnify multiple pivots that are equal to the one we were partitioning with so that
-- whole run of equal pivots can be excluded from recursion.
skipEq :: (PrimMonad m, Eq a, GM.MVector v a) => a -> Int -> v (PrimState m) a -> m Int
skipEq !x !start !v = go start
  where
    !last = GM.length v
    go !k
      | k < last
      = do
        !y <- GM.unsafeRead v k
        if y == x
        then go (k + 1)
        else pure k
      | otherwise
      = pure k

{-# INLINE binlog2 #-}
binlog2 :: Int -> Int
binlog2 x = finiteBitSize x - 1 - countLeadingZeros x
