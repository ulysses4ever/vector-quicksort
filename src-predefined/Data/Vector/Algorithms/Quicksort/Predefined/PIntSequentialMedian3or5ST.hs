-- |
-- Module:     Data.Vector.Algorithms.Quicksort.Predefined.VIntSequentialMedian3or5ST
-- Copyright:  (c) Sergey Vinokurov 2023
-- License:    Apache-2.0 (see LICENSE)
-- Maintainer: serg.foo@gmail.com

module Data.Vector.Algorithms.Quicksort.Predefined.PIntSequentialMedian3or5ST
  ( sortPIntSequentialMedian3or5ST
  ) where

import Control.Monad.ST
import Data.Int
import Data.Vector.Primitive qualified as P

import Data.Vector.Algorithms.Quicksort.Parameterised

import Data.Vector.Algorithms.Quicksort.Predefined.PIntSequentialMedian3ST ()

{-# NOINLINE sortPIntSequentialMedian3or5ST #-}
sortPIntSequentialMedian3or5ST :: P.MVector s Int64 -> ST s ()
sortPIntSequentialMedian3or5ST = sortInplaceFM Sequential (Median3or5 @Int64)

