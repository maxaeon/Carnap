{-#LANGUAGE GADTs, TypeOperators, FlexibleContexts, MultiParamTypeClasses, TypeSynonymInstances, FlexibleInstances, FunctionalDependencies#-}
module Carnap.Calculi.NaturalDeduction.Syntax
where

import Data.Tree
import Data.List (permutations)
import Control.Monad.State
import Carnap.Core.Unification.Unification
import Carnap.Core.Unification.FirstOrder
import Carnap.Core.Unification.ACUI
import Carnap.Core.Data.AbstractSyntaxDataTypes
import Carnap.Core.Data.AbstractSyntaxClasses
import Carnap.Languages.PurePropositional.Syntax
import Carnap.Languages.ClassicalSequent.Syntax
import Carnap.Languages.ClassicalSequent.Parser
import Carnap.Languages.PurePropositional.Parser
--------------------------------------------------------
--1. Data For Natural Deduction
--------------------------------------------------------

class ( FirstOrder (ClassicalSequentOver lex)
      , ACUI (ClassicalSequentOver lex)) => 
        Inference r lex | r -> lex where
        premisesOf :: r -> [ClassicalSequentOver lex Sequent]
        conclusionOf :: r -> ClassicalSequentOver lex Sequent
        --TODO: direct, indirect inferences, template for error messages,
        --etc.

data ProofLine r lex where 
       ProofLine :: Inference r lex => 
            { lineNo  :: Int 
            , content :: ClassicalSequentOver lex Succedent
            , rule    :: r } -> ProofLine r lex

type ProofTree r lex = Tree (ProofLine r lex)

type SequentTree lex = Tree (Int, ClassicalSequentOver lex Sequent)

type ProofErrorMessage = String

--Proof skeletons: trees of schematic sequences generated by a tree of
--inference rules. 

--------------------------------------------------------
--2. Transformations
--------------------------------------------------------

--Proof Tree to Sequent Tree
--
-- Proof Tree to proof skeleton

--------------------------------------------------------
--3. Algorithms
--------------------------------------------------------

reduceProofTree :: (Inference r lang, MaybeMonadVar (ClassicalSequentOver lang) (State Int),
        MonadVar (ClassicalSequentOver lang) (State Int)) =>  
        ProofTree r lang -> Either [ProofErrorMessage] (ClassicalSequentOver lang Sequent)
reduceProofTree (Node (ProofLine no cont rule) ts) =  
        do prems <- mapM reduceProofTree ts
           firstRight $ seqFromNode rule prems cont
               ---TODO: label errors with lineNo

data PropLogic = MP | AX

instance Inference PropLogic PurePropLexicon where
    premisesOf MP = [ GammaV 1 :|-: SS (SeqPhi 1 :->-: SeqPhi 2)
                    , GammaV 2 :|-: SS (SeqPhi 1)
                    ]
    premisesOf AX = []

    conclusionOf MP = (GammaV 1 :+: GammaV 2) :|-: SS (SeqPhi 2)
    conclusionOf AX = SA (SeqPhi 1) :|-: SS (SeqPhi 1)


firstRight :: [Either a [b]] -> Either [a] b
firstRight xs = case filter isRight xs of
                    [] -> Left $ map (\(Left x) -> x) xs
                    (Right (r:x):rs) -> Right r
    where isRight (Right _) = True
          isRight _ = False

--Given a rule and a list of (variable-free) premise sequents, and a (variable-free) 
--conclusion succeedent, return an error or a list of possible (variable-free) correct 
--conclusion sequents
seqFromNode :: (Inference r lang, MaybeMonadVar (ClassicalSequentOver lang) (State Int),
        MonadVar (ClassicalSequentOver lang) (State Int)) =>  
    r -> [ClassicalSequentOver lang Sequent] -> ClassicalSequentOver lang Succedent 
      -> [Either ProofErrorMessage [ClassicalSequentOver lang Sequent]]
seqFromNode rule prems conc = do rprems <- permutations (premisesOf rule)
                                 --XXX:there's premumably a nicer solution
                                 --with monad transfomers
                                 return $ do if length rprems /= length prems 
                                                 then Left "Wrong number of premises"
                                                 else Right ""
                                             let rconc = conclusionOf rule
                                             fosub <- fosolve 
                                                (zipWith (:=:) 
                                                    (map rhs (rconc:rprems)) 
                                                    (conc:map rhs prems))
                                             let subbedrule = map (applySub fosub) rprems
                                             let subbedconc = applySub fosub rconc
                                             acuisubs <- acuisolve 
                                                (zipWith (:=:) 
                                                    (map lhs subbedrule) 
                                                    (map lhs prems))
                                             return $ map (\x -> applySub x subbedconc) acuisubs

fosolve :: (FirstOrder (ClassicalSequentOver lang), MonadVar (ClassicalSequentOver lang) (State Int)) =>  
    [Equation (ClassicalSequentOver lang)] -> Either ProofErrorMessage [Equation (ClassicalSequentOver lang)]
fosolve eqs = case evalState (foUnifySys (const False) eqs) (0 :: Int) of 
                [] -> Left "Unification Error in Rule"
                [s] -> Right s

acuisolve :: (ACUI (ClassicalSequentOver lang), MonadVar (ClassicalSequentOver lang) (State Int)) =>  
    [Equation (ClassicalSequentOver lang)] -> Either ProofErrorMessage [[Equation (ClassicalSequentOver lang)]]
acuisolve eq = 
        case evalState (acuiUnifySys (const False) eq) (0 :: Int) of
          [] -> Left "Unification Error in Assumptions"
          subs -> Right subs

rhs :: ClassicalSequentOver lang Sequent -> ClassicalSequentOver lang Succedent
rhs (x :|-: (Bot :-: y)) = rhs (x :|-: y)
rhs (_ :|-: y) = y 

lhs :: ClassicalSequentOver lang Sequent -> ClassicalSequentOver lang Antecedent
lhs (x :|-: _) = x
