{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DeriveFunctor, DeriveFoldable, DeriveTraversable,DeriveAnyClass #-}
-- {-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE RankNTypes #-}
-- {-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DeriveGeneric, LambdaCase #-}
-- {-# LANGUAGE TemplateHaskell #-}

module Language.Hopper.Internal.Core.ANF  where

-- import Language.Hopper.Internal.Core.Type

import Language.Hopper.Internal.Core.Literal
--import Data.Bifunctor
import Data.Text (Text)
import Data.Data
-- import Data.Word (Word64)
--import Data.Bifunctor.TH
--import Data.Bitraversable
--import Data.Bifoldable
-- import GHC.Generics
-- import  Control.Monad
--import Data.Bifunctor.Wrapped
import Prelude.Extras
-- import Bound hiding (Scope,unscope)
-- import Language.Hopper.Internal.Core.Term
-- import qualified   Bound.Scope.Simple as Simple
import Bound.Var
-- import Bound.Scope.Simple (Scope(..))
-- import Control.Lens (view,over,_1,_2)
import Numeric.Natural
--import Language.Hopper.Internal.Core.Literal




--- data ExpContext  ty a  = SCEmpty
--                         | LetContext
--                             (Maybe Text) -- we're not currently using / needing the variable name here
--                             (Scope (Maybe Text) (Exp ) a)
--                             (ExpContext ty a)
--                         | ThunkUpdate !a (ExpContext ty a)
--                         | FunAppCtxt  [Ref] [Exp ty a] (ExpContext  ty a)
--                           -- lets just treat the ref list as having the function ref at the
--                           -- "bottom of the stack", when [Exp] is empty, reverse ref list to resolve function and apply args
--                         | PrimAppCtxt  PrimOpId [Ref] [Exp ty a] (ExpContext  ty a)

--                         -- applications are their one hole contexts!
--    deriving (Typeable,Functor,Foldable,Traversable,Generic,Data,Eq,Ord,Show)


-- data InterpreterError
--   = PrimopTypeMismatch
--   | NonClosureInApplicationPosition
--   | ArityMismatchFailure
--   | HeapLookupFailure
--   | MalformedClosure
--   | MismatchedStackContext
--   | PrimFailure String
--   | UnsupportedTermConstructFailure String
--   deriving (Eq,Ord,Show,Typeable,Data)


data AppANF  a
    = EnterThunk !a -- if a is neutral term OR a free variable, this becomes neutral
    | FunApp !a ![a] --- if function position of FunApp is neutral, its neutral
    | PrimApp  {-!a -} !Text ![a] -- if any arg of a primop is neutral, its neutral
      --- case / eliminators will also be in this data type later
        deriving ( Ord,Functor,Ord1,Show1,Eq1,Read1,Foldable,Traversable,Typeable,Data,Eq,Read,Show)


data AnfAlloc a
  = SharedLiteral !Literal -- we currently do not have any fixed size literal types
                            -- so for now all literals are heap allocated
                            -- this will change once we add support for stuff like
                            -- Double or Word64
   | ConstrApp {-a is this a resolved qname? -} {-!ty-} !ConstrId [a]
   | AllocateThunk  (ANF   a) -- Thunks share their evaluations
  --  | EvaluateThunk !a       -- Thunk evaluation is a special
  --                           -- no arg lambda plus sharing
                              -- thunks and closure should
                              -- record their free variables???
   | AllocateClosure ![(Either Natural Text{-,Type ty,RigModel-})] -- arity >=0
                             ({-Simple.Scope -} (ANF (Var (Either Natural Text) a)))  -- should we have global table of
                                                              -- "pointers" to lambdas? THINK ME + FIX ME
     deriving (Ord,Ord1,Eq1,Show1,Read1,Functor,Foldable,Traversable,Typeable,Data,Eq,Read,Show)



data AnfRHS  {-ty-} a
    = AnfAllocRHS !(AnfAlloc a) -- only heap allocates, no control flow
    | NonTailCallApp  (AppANF  a) -- control stack allocation; possibly heap allocation

   deriving (Ord,Ord1,Eq1,Show1,Read1,Functor,Foldable,Traversable,Typeable,Data,Eq,Read,Show)


{-
name rep
    binder id :: Word64
    debrujin nexting :: Word64
    sourcename :: Maybe (Fully qualified name)
    sourcloc :: something something something


-}
data ANF  a
    = ReturnNF  ![a] -- !(Atom ty a)
    | LetNF --  (Maybe Text) {-(Maybe(Type ty, RigModel)) -} (AnfRHS  a)
          ![(Either Natural Text)]  -- should be Either Count [Text] later
          !(AnfRHS a) -- only ONE right hand side for now , which may have multiple return values
          -- this list of "independent" simultaneous let bindings must always be nonempty
          -- this is NOT a let rec construct and doesn't provide mutual recursion
          -- this is provided as an artifact of simplifying the term 2 anf translation
          !(ANF (Var (Either Natural Text) a))

          -- (Simple.Scope (Maybe Text) (ANF ) a)
    -- | LetNFMulti ![AnfRHS ty a] !(Scope Word64 (ANF ty) a)
    | TailCallANF (AppANF  a)
    -- future thing will have | LetNFRec maybe?
    deriving (Ord,Ord1,Eq1,Read1,Show1,Functor,Foldable,Traversable,Typeable,Data,Eq,Read,Show)

