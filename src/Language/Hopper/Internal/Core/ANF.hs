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

module Language.Hopper.Internal.Core.ANF  where

import Language.Hopper.Internal.Core.Type
import Language.Hopper.Internal.Core.Literal
import Data.Text (Text)
import Data.Data
-- import Data.Word (Word64)

-- import GHC.Generics
import  Control.Monad
import Prelude.Extras
-- import Bound hiding (Scope,unscope)
-- import Language.Hopper.Internal.Core.Term
import qualified   Bound.Scope.Simple as Simple
-- import Bound.Scope.Simple (Scope(..))
-- import Control.Lens (view,over,_1,_2)



-- scopedAnf2ScopedExp :: Scope b (ANF ty) a ->  (Scope b (Exp ty) a)
-- scopedAnf2ScopedExp   scp= Scope $  (anf2Exp   (fmap (fmap ( anf2Exp )) $ unscope scp ))

-- anf2Exp ::  ANF ty a -> (Exp ty a)
-- anf2Exp (ReturnNF a) = (pure a)
-- anf2Exp (LetNF mname mtype rhs scp) = (Let mname mtype (rhs2Exp rhs) $  scopedAnf2ScopedExp  scp )
-- anf2Exp (TailCallANF app) = appANF2Exp  app

-- rhs2Exp ::   AnfRHS ty a ->  (Exp ty a)
-- rhs2Exp  (SharedLiteral l) = ELit l
-- rhs2Exp  (ConstrApp a  _ty _conid lsargs) =  (pure a :@  fmap pure lsargs)
-- rhs2Exp (AllocateThunk e) = Delay $ anf2Exp  e
-- rhs2Exp (AllocateClosure binders scp) =  Lam binders (scopedAnf2ScopedExp  scp)
-- rhs2Exp  (NonTailCallApp app) = appANF2Exp  app



-- appANF2Exp :: AppANF ty a ->  (Exp ty a)
-- appANF2Exp (EnterThunk a) =   Force (pure a)
-- appANF2Exp (FunApp a argLS) =  pure a :@ map pure argLS
-- appANF2Exp (PrimApp a _txt argLS) = pure a :@ map pure argLS



-- exp2Anf :: Exp ty a -> ANF ty a
-- exp2Anf (V a) = pure a
-- exp2Anf (ELit l) = LetNF Nothing Nothing (SharedLiteral l) (Scope $ pure $ B Nothing)
-- exp2Anf (Delay e) = LetNF Nothing Nothing (AllocateThunk (exp2ANF e)) (Scope $ pure $ B Nothing)
-- exp2Anf (Lam binders scope) = LetNF Nothing Nothing
--           (AllocateClosure binders $ Scope $ exp2ANF $ (fmap $ fmap exp2ANF)$ unscope scope)
--             (Scope $  pure $ B Nothing )
-- exp2Anf (Force expr) = exp2ANFComp expr (\var -> TailCallANF (EnterThunk var))
-- exp2Anf (Let mname mtyp rhsExp  scpBod) = exp2anfRHS rhsExp
--                                          (\rhsANF -> LetNF mname mtyp rhsANF  $ underScopeANF2Exp scpBod)
-- exp2Anf (funExp :@ [])        =
-- exp2Anf (funExp :@ [e1])      =
-- exp2Anf (funExp :@ (he : te)) =


-- exp2AnfComp :: Exp ty a -> (a -> ANF ty a) -> ANF ty a
-- exp2ANFComp (V a) f = f a

{-
what we roughly want to do is take
f a1 ... am and transform it into
n1 = f a1
n2 = n1 a2
...
n(i+1) = ni a(i+1)
...

and then flatten out again at the end by tracking these
let applications are being distinguished from normal let bindings

now, the main insight / trick is to ... instead of having a distinguished form of let,
we simply use a function instead (within a continuation of course !)

-}

-- exp2anfRHS :: Exp ty a -> (AnfRHS ty a -> ANF ty a ) -> ANF ty a
-- exp2anfRHS = undefined

-- underScopeANF2Exp :: Scope b (Exp ty) a -> Scope b (ANF ty) a
-- underScopeANF2Exp scp = Scope $ exp2ANF $ (fmap $ fmap exp2ANF)$ unscope scp

-- exp2ANFComp :: (Exp ty a) -> (a -> ANF ty a) -> ANF ty a
-- exp2ANFComp e k = undefined



-- | the right hand side of a LetNF, aka 'AnfRHS' is the point where heap allocation of thunks happens
-- the only other
data AnfRHS ty a = SharedLiteral !Literal -- we currently do not have any fixed size literal types
                                          -- so for now all literals are heap allocated
                                          -- this will change once we add support for stuff like
                                          -- Double or Word64
                 | ConstrApp a !ty !ConstrId [a]
                 | AllocateThunk (ANF ty a) -- Thunks share their evaluations
                --  | EvaluateThunk !a       -- Thunk evaluation is a special
                --                           -- no arg lambda plus sharing
                                            -- thunks and closure should
                                            -- record their free variables???
                 | AllocateClosure ![(Text,Type ty,RigModel)] -- arity >=0
                                   (Simple.Scope Text (ANF ty)  a)  -- should we have global table of
                                                              -- "pointers" to lambdas? THINK ME + FIX ME

                 | NonTailCallApp  (AppANF ty a) -- control stack allocation; possibly heap allocation


   deriving (Ord,
    Functor,
    Foldable,
    Traversable,
    Typeable,
    Data,
    Eq,
    Read,
    Show)
instance Eq ty => Eq1 (AnfRHS ty)
instance Show ty => Show1 (AnfRHS ty)
instance Ord ty => Ord1 (AnfRHS ty)
instance Read ty => Read1 (AnfRHS ty)

instance Eq2 AnfRHS
instance Show2 AnfRHS
instance Ord2 AnfRHS
instance Read2 AnfRHS
-- data ArgANF ty a = ArgVar a | ArgLit !Literal


data AppANF ty a = EnterThunk a
                 | FunApp a ![a]
                 | PrimApp  a !Text ![a]
        deriving ( Ord,
         Functor,
         Foldable,
         Traversable,
         Typeable,
         Data,
         Eq,
         Read,
         Show)

instance Eq ty => Eq1 (AppANF ty)
instance Show ty => Show1 (AppANF ty)
instance Ord ty => Ord1 (AppANF ty)
instance Read ty => Read1 (AppANF ty)

instance Eq2 AppANF
instance Show2 AppANF
instance Ord2 AppANF
instance Read2 AppANF


data ANF ty a
    = ReturnNF  !a -- !(Atom ty a)
    | LetNF (Maybe Text) (Maybe(Type ty, RigModel)) (AnfRHS ty a) (Simple.Scope (Maybe Text) (ANF ty) a)
    -- | LetNFMulti ![AnfRHS ty a] !(Scope Word64 (ANF ty) a)
    | TailCallANF (AppANF ty a)
    -- future thing will have | LetNFRec maybe?
    deriving (Ord,
      Functor,
      Foldable,
      Traversable,
      Typeable,
      Data,
      Eq,
      Read,
      Show)
instance Eq ty => Eq1 (ANF ty)
instance Show ty => Show1 (ANF ty)
instance Ord ty => Ord1 (ANF ty)
instance Read ty => Read1 (ANF ty)

instance Eq2 ANF
instance Show2 ANF
instance Ord2 ANF
instance Read2 ANF

-- l2rJoinANF :: forall ty a . (ANF ty (ANF ty a)) -> (ANF ty a)
-- l2rJoinANF (ReturnNF a) = a
-- l2rJoinANF (LetNF rhs bod) = l2rCanonicalRHS rhs (Scope $ fmap (fmap l2rJoinANF) $ unscope bod)
--
-- l2rCanonicalRHS :: AnfRHS ty (ANF ty a)
--                 -> ((Scope () (ANF ty) a)
--                 -> ANF ty a)
-- l2rCanonicalRHS (AllocateThunk e) scp = LetNF (AllocateThunk $ l2rJoinANF e) scp
-- l2rCanonicalRHS (SharedLiteral l) scp = LetNF (SharedLiteral l) scp
-- l2rCanonicalRHS (AllocateClosure ls bod) scp = LetNF (AllocateClosure ls $ Scope $ fmap (fmap l2rJoinANF) $ unscope bod) scp

{-
AUDIT: should we just be doing the too / from scope functions?

-}
--flattenUnderScope :: Scope b (ANF ty) (ANF ty a) -> Scope b (ANF ty) a
--flattenUnderScope = Scope . fmap (fmap danvyANF) . unscope



--zoomToTailPosition :: forall a ty . (forall c . c -> ANF ty c) ->  ANF ty a -> ANF ty a
--zoomToTailPosition f (ReturnNF a)  = f a
--zoomToTailPosition f (TailCallANF app)  = LetNF Nothing Nothing (NonTailCallApp app)
--                                           (Scope $ f (B Nothing ))
--zoomToTailPosition f (LetNF mebeName mebeCut  rhs bod)  =   LetNF  mebeName mebeCut rhs
--                                          (Scope $ (fmap $ fmap $ zoomToTailPosition f) $ unscope bod)
---- zoomToTailPosition f (LetNFMulti rhss bod) = LetNFMulti rhss
----                     (Scope $ (fmap $ fmap $ zoomToTailPosition f) $ unscope bod)

--danvyANF :: (ANF ty (ANF ty a)) -> ANF ty a
--danvyANF (ReturnNF a) = a
--danvyANF (TailCallANF app) = danvyTailCallAppANF app
--danvyANF (LetNF mname mtype rhs bod) = danvyRHS rhs (\r -> LetNF mname mtype r $  flattenUnderScope bod)

--danvyRHS :: (AnfRHS ty (ANF ty a)) -> (AnfRHS ty a -> ANF ty a) -> ANF ty a
--danvyRHS (SharedLiteral l)  f =  f $ SharedLiteral l
--danvyRHS (AllocateThunk expr) f = f $ AllocateThunk $ danvyANF expr
--danvyRHS (AllocateClosure args scp) f = f $ AllocateClosure args (flattenUnderScope scp)
---- danvyRHS (NonTailCallApp app) f = danvyNotTailCallANF app  f


--danvyExp2RhsANF :: (ANF ty a) -> ( a -> ANF ty a) -> ANF ty a
--danvyExp2RhsANF = error "{ this is TERRRRIBLEEEEEEE }"
---- danvyExp2RhsANF (ReturnNF v) f = f v
---- danvyExp2RhsANF (TailCallANF app) f = danvyNotTailCallANF app (\ rhs -> LetNF rhs )


--danvyTailCallAppANF :: (AppANF ty (ANF ty a)) {- } -> (AppANF ty a -> ANF ty a )-} -> ANF ty a
--danvyTailCallAppANF (EnterThunk (ReturnNF x)) =  LetNF  Nothing Nothing (NonTailCallApp (EnterThunk x))
--                                                  (Scope  $ ReturnNF(B Nothing ))
--danvyTailCallAppANF (EnterThunk (TailCallANF app)) =
--                                            LetNF Nothing Nothing
--                                              (NonTailCallApp app)
--                                              (Scope $ (
--                                                ( LetNF Nothing Nothing (NonTailCallApp (EnterThunk (B Nothing)))
--                                                      (Scope $ ReturnNF (B Nothing ))
--                                                      )))
--danvyTailCallAppANF (EnterThunk lt@(LetNF _ _ _ _))=
--          zoomToTailPosition (\ x -> LetNF Nothing Nothing (NonTailCallApp $ EnterThunk x )
--                                            (Scope $ ReturnNF (B Nothing ))
--                                          )
--                              lt
--danvyTailCallAppANF (PrimApp  a nm args)
--      | all (\case {(ReturnNF _) -> True ; _ -> False }) args =
--                             TailCallANF $   PrimApp  ((\(ReturnNF x) -> x ) a) nm (map (\(ReturnNF x)-> x) args)
--      | otherwise = error "demoware FAILURE, will be fixed in next iteration, primp apps must be saturated"
--      --- this is our base case for the binary app hack
--danvyTailCallAppANF (FunApp (ReturnNF f) [ReturnNF v])  = TailCallANF $ FunApp f [v]
--danvyTailCallAppANF (FunApp (ReturnNF f) []) =  TailCallANF $ FunApp f []
--danvyTailCallAppANF (FunApp f  (h:t)) =
--    danvyExp2RhsANF f (\ fv -> ( danvyExp2RhsANF h   (\v  ->
--              LetNF Nothing Nothing (NonTailCallApp (FunApp fv [v])) $
--                    Scope $
--                        danvyTailCallAppANF
--                          (FunApp (ReturnNF $ B Nothing)
--                                   _whoam-- ( map (fmap F) t )
--                                  ) )))



--danvyNotTailCallANF :: (AppANF ty (ANF ty a)) -> ( a -> ANF ty a) -> ANF ty a
--danvyNotTailCallANF (EnterThunk a) f =  error "dskfjdklfj"-- danvyExp2RhsANF a (\ var -> f $ NonTailCallApp
--                                                                     -- $ EnterThunk var  )


{- traverse from right to left using Reverse or Backwards applicative
over State, accumulating continuations of the inner scopes that are the
later evaluation steps
  -}

instance Applicative (ANF ty) where
  pure  = \x -> ReturnNF  x
  (<*>) = ap

instance Monad (ANF ty) where
  m >>= f =  (error "womp womp womp") $ fmap f m
 {- (afun :@@ aargs) >>= f =
        LetNF subst'dArgs :: forall a b .  (a -> ANF ty b) -> [Atom ty a]-> [ANF ty b]
            subst'dArgs  g  ls = fmap (unVar . fmap g) ls
            foldrList :: forall a b . (a -> b -> b) -> b -> [a] -> b
            foldrList = foldr
            cps'dArgs :: _sdfdsfdsf
            cps'dArgs = foldrList  cpsStacking id  (subst'dArgs f aargs)
            -- cpsStacking :: forall  a  . ( ) -> (a -> ANF ty a) -> (a -> ANF ty a)
            cpsStacking = _lalala
        in  (f $ unVar $ afun) `cpsStacking` cps'dArgs-}
  -- (LetNF aRHS aBod) >>= f = _dderp
  -- (ReturnNF (AtomicLit l)) >>= _f = ReturnNF $ AtomicLit l
  -- (ReturnNF (AtomLam bs bod)) >>= f = ReturnNF $ AtomLam bs (bod >>>= f)
  --( ( ) :@@ )

  -- return = V
  --V a         >>= f = f a
  --Delay e     >>= f = Delay $ e >>= f
  --Force e     >>= f = Force $ e >>= f
  --ELit e      >>= _f = ELit e -- this could also safely be a coerce?
  --(x :@ y)    >>= f = (x >>= f) :@ (y >>= f)
  --Lam t  e    >>= f = Lam t (e >>>= f)
  --LetNF t bs  b >>= f = LetNF t (  bs >>= f)  (b >>>= f)
