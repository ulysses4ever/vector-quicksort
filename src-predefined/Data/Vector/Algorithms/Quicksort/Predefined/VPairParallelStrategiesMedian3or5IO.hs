----------------------------------------------------------------------------
-- |
-- Module      :  Data.Vector.Algorithms.Quicksort.Predefined.VPairParallelStrategiesMedian3or5IO
-- Copyright   :  (c) Sergey Vinokurov 2023
-- License     :  Apache-2.0 (see LICENSE)
-- Maintainer  :  serg.foo@gmail.com
----------------------------------------------------------------------------

module Data.Vector.Algorithms.Quicksort.Predefined.VPairParallelStrategiesMedian3or5IO
  ( sortVPairParallelStrategiesMedian3or5IO
  ) where

import Control.Monad.ST
import Data.Int
import Data.Vector qualified as V

import Data.Vector.Algorithms.Quicksort qualified as Quick
import Data.Vector.Algorithms.Quicksort.Fork
import Data.Vector.Algorithms.Quicksort.Median


{-# NOINLINE sortVPairParallelStrategiesMedian3or5IO #-}
sortVPairParallelStrategiesMedian3or5IO :: V.MVector RealWorld (Int32, Int32) -> IO ()
sortVPairParallelStrategiesMedian3or5IO = Quick.sort ParStrategies (Median3or5 @(Int32, Int32))


