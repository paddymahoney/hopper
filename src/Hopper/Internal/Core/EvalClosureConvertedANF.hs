{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DeriveFunctor, DeriveFoldable, DeriveTraversable,DeriveAnyClass #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}
module Hopper.Internal.Core.EvalClosureConvertedANF where

import Hopper.Internal.Core.ClosureConvertedANF
import Hopper.Internal.Runtime.Heap
import Hopper.Internal.Runtime.HeapRef
import Data.Hop.Or
import Control.Monad.STE
import Data.Data
import GHC.Generics
import qualified Data.Vector as V

-- | CCAnfEnvStack will eventually blur into whatever register allocation execution model we adopt
data EnvStackCC =
    EnvConsCC !Ref !EnvStackCC
    | EnvEmptyCC
  deriving (Eq,Ord,Show,Read,Typeable,Data,Generic)
data ControlStackCC  =
      LetBinderCC !(V.Vector BinderInfoCC)
                !()
                !AnfCC --- body of let
                !ControlStackCC -- what happens after the body of let returns!
      | ControlStackEmptyCC  -- we're done!
      | UpdateHeapRefCC
            !Ref
            !ControlStackCC
  deriving (Eq,Ord,Show,Read,Typeable,Data,Generic)

data CCAnfEvalError

evalCCAnf :: CodeRegistry -> EnvStackCC -> ControlStackCC -> AnfCC -> HeapStepCounterM (ValueRepCC Ref) (STE (c :+ CCAnfEvalError :+ HeapError ) s) [Ref]
evalCCAnf = error "finish this next week"

-- evalANF ::  Anf Ref -> ControlStackAnf -> HeapStepCounterM hepRep (STE (c :+ ErrorEvalAnf :+ HeapError ) s) Ref