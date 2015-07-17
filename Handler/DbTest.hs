module Handler.DbTest where

import Import
import Data.List
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
-- import           Data.Set (Set)
-- import qualified Data.Set as Set
import Presenter.PersistHelper
import Presenter.Model.Entities()

type JobPairId = Int

data Attribute = ASolverName Text | ASlowCpuTime Bool | ASolverResult SolverResult
 deriving (Eq, Ord, Show)


data JobPairAttributes = JobPairAttributes
  { benchmarkId :: Int
  , solverName  :: Text
  , slowCpuTime :: Bool
  , solverResult :: SolverResult
  } deriving (Show)


-- all job pairs with a response time greater 10 seconds is slow
slowCpuTimeLimit :: ((Num Double, Ord Double)) => Double
slowCpuTimeLimit = 10.0


getDbTestR :: JobID -> Handler Html
getDbTestR jid = do
  jobResults <- getPersistJobResults jid
  let objAttrRel = createObjectAttributeRelation $ getStarExecResults jobResults
  let attrObjRel = createAttributeObjectReleation objAttrRel
  -- let concepts = createConcepts objAttrRel attrObjRel

  -- let x = Map.toList objAttrRel
  -- let xn = length $ x
  -- #{show xn}
  -- #{show $ length concepts}
  -- #{show concepts}
  defaultLayout [whamlet|
    <h1>Objects an its attributes
    <ul>
    $forall (jobPairId, jobPairAttributes) <- Map.toList objAttrRel
      <li> #{show jobPairId}: #{show jobPairAttributes}
    <h1>Attributes with its objects
    <ul>
    $forall (attr, objects) <- Map.toList attrObjRel
      <li> #{show attr}: #{show objects}
    |]
    -- <ul>
    -- $forall jobResult <- getStarExecResults jobResults
    --   <li> #{show jobResult}


createConcepts :: Map JobPairId JobPairAttributes -> Map Attribute [JobPairId] -> [[JobPairId]]--[([JobPairId], [JobPairAttributes])]
createConcepts objAttrRel attrObjRel = do
  take 20 $ subsequences $ Map.keys objAttrRel
  --let objectSubsets = (take 20 $ subsequences $ Map.keys objAttrRel :: [[JobPairId]])
  -- nice would be:
  --map 
  --  ((\(objs, attrs, attrsObj) -> (objs, attrs))
  -- . (getCommonObjects attrObjRel)
  -- . (getCommonAttributes objAttrRel))
  -- objectSubsets


getCommonAttributes :: [JobPairId] -> Map JobPairId JobPairAttributes -> ([JobPairId], [JobPairAttributes])
getCommonAttributes = undefined


getCommonObjects :: ([JobPairId], [JobPairAttributes]) -> Map Attribute [JobPairId] -> ([JobPairId], [JobPairAttributes], [JobPairId])
getCommonObjects = undefined


createObjectAttributeRelation :: [JobResultInfo] -> Map JobPairId JobPairAttributes
createObjectAttributeRelation jobResults = do
  let jobResultInfoPairIds = map (jobResultInfoPairId) jobResults
  let attrs = getAttributeCollection jobResults
  let objAttrRel = zip jobResultInfoPairIds attrs
  Map.fromList objAttrRel


createAttributeObjectReleation :: Map JobPairId JobPairAttributes -> Map Attribute [JobPairId]
createAttributeObjectReleation objAttrRel = do
  let objAttrs = Map.toList objAttrRel
  -- very ugly and to explicit!
  let cpuTimes = map (\(a,b) -> (a, slowCpuTime b)) objAttrs
  let slowCpuTimes = map (\(a,_) -> a) $ filter (\(_,b) -> b == True) cpuTimes
  let fastCpuTimes = map (\(a,_) -> a) $ filter (\(_,b) -> b == False) cpuTimes
  
  let solverResults = map (\(a,b) -> (a, solverResult b)) objAttrs
  let maybeSolverResults = map (\(a,_) -> a) $ filter (\(_,b) -> b == MAYBE) solverResults
  -- let otherSolverResults = map (\(a,_) -> a) $ filter (\(_,b) -> b == OTHER) solverResults

  let attrsObjRel = Map.insert (ASlowCpuTime True) slowCpuTimes Map.empty
  let attrsObjRels = Map.insert (ASlowCpuTime False) fastCpuTimes attrsObjRel
  Map.insert (ASolverResult MAYBE) maybeSolverResults attrsObjRels


getAttributeCollection :: [JobResultInfo] -> [JobPairAttributes]
getAttributeCollection jobResults = do
  -- would it be better to remove some attributes of the existing record?
  let jobResultInfoBenchmarkIds = map (jobResultInfoBenchmarkId) jobResults
  let jobResultInfoSolvers = map (jobResultInfoSolver) jobResults
  let cpuTimeEvaluations = evaluateCpuTime jobResults
  let jobResultInfoResults = map (jobResultInfoResult) jobResults
  let attrs = zip4 jobResultInfoBenchmarkIds jobResultInfoSolvers cpuTimeEvaluations jobResultInfoResults
  map (\(a,b,c,d)-> JobPairAttributes {benchmarkId = a, solverName = b, slowCpuTime = c, solverResult = d}) attrs

evaluateCpuTime :: [JobResultInfo] -> [Bool]
evaluateCpuTime = map ((> slowCpuTimeLimit). jobResultInfoCpuTime)
