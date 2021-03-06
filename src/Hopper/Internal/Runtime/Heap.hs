{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DeriveFunctor, DeriveFoldable, DeriveTraversable,DeriveAnyClass #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeFamilies, TypeOperators #-}

module Hopper.Internal.Runtime.Heap(
  HeapError(..)
  ,HeapStepCounterM  -- keeping HeapStepCounterM abstract for now, as long as theres NO TH hijinks
  ,unsafeHeapUpdate
  ,unsafeRunHSCM
  ,runEmptyHeap
  ,heapAllocate
  ,heapLookup
  ,checkedCounterIncrement
  ,checkedCounterJump
  ,throwHeapErrorWithStepInfoSTE
  ,TransitiveLookup(..)
  )

    where

import qualified Data.Map as Map
import GHC.Generics
import Numeric.Natural
import Data.Typeable
import Control.Monad.Trans.State.Strict as State
-- import Prelude.Extras
import Control.Monad.Trans.Class as MT
import Control.Monad.Primitive as  Prim
import Control.Monad.IO.Class as MIO
import  Control.Monad.STE
import Data.Data
import Data.Hop.Or
import Hopper.Internal.Runtime.HeapRef



class TransitiveLookup valRep  where
   --{-# INLINABLE transitiveHeapLookup #-}
   transitiveHeapLookup :: Ref -> forall c . HeapStepCounterM valRep (STE (c  :+ HeapError ) s) (Natural,valRep)


throwHeapErrorWithStepInfoSTE :: (Natural -> err) -> HeapStepCounterM val (STE err  s) result
throwHeapErrorWithStepInfoSTE f =
                            do  cah <- getHSCM
                                ct <- return $  _extractStepCounterCAH cah
                                lift $ throwSTE $! (f ct)

data Heap val  =  Heap { _minMaxFreshRef :: !Ref,  _theHeap :: ! (Map.Map Ref val)   }
   deriving (  Typeable  , Eq, Ord, Show, Functor,Foldable,Traversable ,Generic,Data)


data HeapError
  = HeapStepCounterExceeded
  | InvalidHeapLookup
  | HeapLookupOutOfBounds
  deriving (Eq,Ord,Show,Read,Typeable)

throwHeapError :: MonadTrans t => HeapError -> t (STE (a1 :+ HeapError) s) a
throwHeapError e = lift $ throwSTE $ InR e

heapRefUpdate :: Ref -> val  -> Heap val  -> HeapStepCounterM val (STE (b :+ HeapError ) s) (Heap val)
heapRefUpdate ref val (Heap ct mp)
        | ref < ct  && ref `Map.member` mp = return $ Heap ct $ Map.insert ref val mp
        | ref >= ct = throwHeapError HeapLookupOutOfBounds -- error $ "impossible heap ref greater than heap max, deep invariant failure" ++ show ref
        | otherwise {- invalid heap ref -} = throwHeapError InvalidHeapLookup

heapAllocateValue :: Heap val   -> val   -> (Ref,Heap val  )
heapAllocateValue hp val = (_minMaxFreshRef hp
                            , Heap (Ref $ (refPointer minmax) + 1) newMap)
  where
      minmax = _minMaxFreshRef hp
      newMap = Map.insert minmax  val (_theHeap hp)

data CounterAndHeap val  =  CounterAndHeap {
                                        _extractStepCounterCAH :: !Natural
                                        -- this should be a Natural, represents  number of
                                        -- steps l
                                        ,_extractMaxStepCounter :: !Natural
                                        ,_extractHeapCAH :: !(Heap val ) }
                            deriving (

                                      Typeable


                                      ,Eq,Ord,Show
                                      ,Foldable
                                      ,Traversable
                                      ,Functor
                                      )


newtype HeapStepCounterM val  m a = HSCM {_xtractHSCM :: State.StateT  (CounterAndHeap val ) m a}
   deriving (Typeable,Functor)

instance MonadIO m => MonadIO (HeapStepCounterM val m) where
  liftIO m = lift $ MIO.liftIO m

instance PrimMonad m => PrimMonad (HeapStepCounterM val m) where
  type PrimState (HeapStepCounterM val m) = Prim.PrimState m
  primitive stfun = lift $ Prim.primitive stfun
instance MT.MonadTrans (HeapStepCounterM val) where
    lift m =  HSCM $ StateT (\ s -> fmap (\i -> (i,s)) m)
instance Monad  n=>Applicative (HeapStepCounterM val  n) where
    pure  = \v ->  HSCM $ pure v
    (<*>) = \ (HSCM f) (HSCM v) -> HSCM $ f <*> v
instance Monad m => Monad (HeapStepCounterM val m) where
    return = pure
    (>>=)= \ (HSCM mv) f -> HSCM (mv  >>= (_xtractHSCM. f))

getHSCM ::Monad m => HeapStepCounterM val  m (CounterAndHeap val )
getHSCM  = HSCM State.get

setHSCM ::Monad m =>  CounterAndHeap val   -> HeapStepCounterM  val  m  ()
setHSCM v = HSCM $ State.put  v


{- this is how we track number of reduction steps deterministically
may be a useful way of "addressing" a point in a programs execution
within a debugging tool at some future point -}
checkedCounterIncrement ::   HeapStepCounterM  val  (STE (b :+ HeapError ) s) ()
checkedCounterIncrement =  checkedCounterJump 1

checkedCounterJump ::  Natural ->  HeapStepCounterM  val  (STE (b :+ HeapError ) s) ()
checkedCounterJump  jumpSize =
                          do  cah <- getHSCM
                              ct <- return $  _extractStepCounterCAH cah
                              if ct > _extractMaxStepCounter cah
                               then throwHeapError HeapStepCounterExceeded-- error "allowed step count exceeded, aborting"
                               else setHSCM cah{_extractStepCounterCAH = ct + jumpSize}


unsafeHeapUpdate :: Ref -> val  -> HeapStepCounterM val (STE (b :+ HeapError ) s) ()
unsafeHeapUpdate rf val = do  cah <- getHSCM
                              x <-  heapRefUpdate rf val (_extractHeapCAH cah)
                              checkedCounterIncrement
                              x `seq` setHSCM $ cah{_extractHeapCAH =x }

--- note, this should also decrement the counter!
heapAllocate :: val  -> HeapStepCounterM  val  (STE (b :+ HeapError ) s) Ref
heapAllocate val = do   cah <-  getHSCM
                        (rf,hp) <- pure $ heapAllocateValue (_extractHeapCAH cah) val
                        cah' <- pure $ cah{_extractHeapCAH = hp}
                        checkedCounterIncrement
                        setHSCM cah'
                        return rf

heapLookup :: Ref -> forall b. HeapStepCounterM val (STE (b :+ HeapError) s) val
heapLookup ref = do
  checkedCounterIncrement
  heapHandle <- _extractHeapCAH <$> getHSCM
  heapRefLookup ref heapHandle
   where
     heapRefLookup :: Ref -> Heap val -> HeapStepCounterM val (STE (b :+ HeapError) s) val
     heapRefLookup rf (Heap ct mp)
       | ref < ct && rf `Map.member` mp = return $ mp Map.! rf
       | ref >= ct = throwHeapError HeapLookupOutOfBounds
       | otherwise {- invalid heap ref -} = throwHeapError InvalidHeapLookup


--- this doesn't validate Heap and heap allocator correctness, VERY UNSAFE :)
unsafeRunHSCM :: Monad m =>  Natural -> Heap val  -> HeapStepCounterM val m b -> m (b,CounterAndHeap val  )
unsafeRunHSCM cnt hp (HSCM m)  = State.runStateT m (CounterAndHeap 0 cnt hp)

-- run a program in an empty heap
runEmptyHeap :: Monad m =>  Natural -> HeapStepCounterM val m  b-> m (b,CounterAndHeap val )
runEmptyHeap ct (HSCM m) = State.runStateT m (CounterAndHeap 0 ct $ Heap (Ref 1) Map.empty)
