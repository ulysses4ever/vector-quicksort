----------------------------------------------------------------------------
-- |
-- Module      :  Data.Vector.Algorithms.Quicksort.Predefined.VIntParallelStrategiesMedian3or5ST
-- Copyright   :  (c) Sergey Vinokurov 2023
-- License     :  Apache-2.0 (see LICENSE)
-- Maintainer  :  serg.foo@gmail.com
----------------------------------------------------------------------------

module Data.Vector.Algorithms.Quicksort.Predefined.PIntParallelStrategiesMedian3or5ST
  ( sortPIntParallelStrategiesMedian3or5ST
  ) where

import Control.Monad.ST
import Data.Int
import Data.Vector.Primitive qualified as P

import Data.Vector.Algorithms.Quicksort qualified as Quick
import Data.Vector.Algorithms.Quicksort.Fork
import Data.Vector.Algorithms.Quicksort.Median


{-# NOINLINE sortPIntParallelStrategiesMedian3or5ST #-}
sortPIntParallelStrategiesMedian3or5ST :: P.MVector s Int64 -> ST s ()
sortPIntParallelStrategiesMedian3or5ST = Quick.sort ParStrategies (Median3or5 @Int64)

