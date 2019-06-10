-- Copyright 2019 Google LLC
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file or at
-- https://developers.google.com/open-source/licenses/bsd

{-# LANGUAGE CPP #-}
module GHC.SourceGen.Binds.Internal where

import BasicTypes (Origin(Generated))
import Bag (listToBag)
import HsBinds
import HsExpr (MatchGroup(..), Match(..), GRHS(..), GRHSs(..))
import SrcLoc (Located)

#if !MIN_VERSION_ghc(8,6,0)
import PlaceHolder (PlaceHolder(..))
#endif


import GHC.SourceGen.Syntax
import GHC.SourceGen.Syntax.Internal

data RawValBind
    = SigV Sig'
    | BindV HsBind'

valBinds :: [RawValBind] -> HsLocalBinds'
-- This case prevents GHC from printing an empty "where" clause:
valBinds [] = noExt EmptyLocalBinds
valBinds vbs =
    noExt HsValBinds
#if MIN_VERSION_ghc(8,6,0)
        $ noExt ValBinds
#else
        $ noExt ValBindsIn
#endif
            (listToBag $ map builtLoc binds)
            (map builtLoc sigs)
  where
    sigs = [s | SigV s <- vbs]
    binds = [b | BindV b <- vbs]

-- | A single function pattern match, including an optional "where" clause.
--
-- For example:
--
-- > f x
-- >    | cond = y
-- >    | otherwise = z
-- >  where
-- >    y = ...
-- >    z = ...
data RawMatch = RawMatch
    { rawMatchPats :: [Pat']
    , rawGRHSs :: [RawGRHS]
    , rawWhere :: [RawValBind]
    }


matchGroup :: HsMatchContext' -> [RawMatch] -> MatchGroup' (Located HsExpr')
matchGroup context matches =
    noExt MG (builtLoc $ map (builtLoc . mkMatch) matches)
#if !MIN_VERSION_ghc(8,6,0)
                            [] PlaceHolder
#endif
                            Generated
  where
    mkMatch :: RawMatch -> Match' (Located HsExpr')
    mkMatch r = noExt Match context (map builtPat $ rawMatchPats r)
#if !MIN_VERSION_ghc(8,4,0)
                    -- The GHC docs say: "A type signature for the result of the match."
                    -- The parsing step produces 'Nothing' for this field.
                    Nothing
#endif
                    $ noExt GRHSs (map (builtLoc . mkGRHS) $ rawGRHSs r)
                            (builtLoc $ valBinds $ rawWhere r)

-- | The "right-hand-side" of a function definition.  For example:
--
-- > f x | y = z
data RawGRHS = RawGRHS [Stmt'] HsExpr'

mkGRHS :: RawGRHS -> GRHS' (Located HsExpr')
mkGRHS (RawGRHS stmts e) = noExt GRHS (map builtLoc stmts) (builtLoc e)


