----------------------------------------------------------------------------
-- |
-- Module      :  Data.Vector.Algorithms.Quicksort.Predefined.VIntSequentialMedian3IO
-- Copyright   :  (c) Sergey Vinokurov 2023
-- License     :  Apache-2.0 (see LICENSE)
-- Maintainer  :  serg.foo@gmail.com
----------------------------------------------------------------------------

module Data.Vector.Algorithms.Quicksort.Predefined.VIntSequentialMedian3IO
  ( sortVIntSequentialMedian3IO
  ) where

import Control.Monad.ST
import Data.Int
import Data.Vector qualified as V

import Data.Vector.Algorithms.Quicksort qualified as Quick
import Data.Vector.Algorithms.Quicksort.Fork
import Data.Vector.Algorithms.Quicksort.Median


{-# NOINLINE sortVIntSequentialMedian3IO #-}
sortVIntSequentialMedian3IO :: V.MVector RealWorld Int64 -> IO ()
sortVIntSequentialMedian3IO = Quick.sort Sequential (Median3 @Int64)

