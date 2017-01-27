
module CommunicationAnalysis
    (
        communicationAnalysis,
        routeXY
    )
where

import ResponseTimeAnalysis
import Structures
import Utils

import qualified Data.Map as M
import Data.Maybe
import Data.List

type IdLookup = (M.Map TaskId Task, M.Map CoreId Core)

lookupTasks :: M.Map TaskId Task -> M.Map TaskId v -> M.Map Task v
lookupTasks idLookup m = M.fromList . map get $ M.toList m
    where
        get (tid, v1) = (fromMaybe (error "Task not in task lookup") $ M.lookup tid idLookup, v1)

core :: TaskId -> TaskMapping -> CoreId
core t tm = fromMaybe (error "Task not in task mapping") $ M.lookup t tm

location :: TaskId -> Application -> Location
location taskId (_, _, tm, cm) = fromMaybe (error "Core not in core mapping") $ M.lookup c cm
    where
        c = core taskId tm

directInterferenceSet :: Task -> M.Map Task TrafficFlow -> [Task]
directInterferenceSet t tfs = M.keys . M.filter (not . null . intersect tFlow) $ hpts
    where
        tFlow = fromMaybe (error "Traffic flow not in map") $ M.lookup t tfs 
        hpts = M.filterWithKey (\kt _ -> tPriority kt > tPriority t) tfs

routeXY :: Location -> Location -> TrafficFlow
routeXY (ar, ac) (br, bc)
    | (ar, ac) == (br, bc) = []
    | otherwise = cur : routeXY next (br, bc)
    where
        next = case compare ac bc of
            LT -> nextCol succ
            GT -> nextCol pred
            EQ -> case compare ar br of
                LT -> nextRow succ
                GT -> nextRow pred
        cur = ((ar, ac), next) :: Link
        nextCol dir = (ar, dir ac)
        nextRow dir = (dir ar, ac)

route :: Task -> Application -> TrafficFlow
route t a = routeXY sLoc dLoc
    where
        sLoc = lf . tId $ t
        dLoc = lf . cDestination . tCommunication $ t
        lf x = location x a

tasksOnCore :: Core -> Application -> M.Map TaskId Task -> [Task]
tasksOnCore c (_, ts, tm, _) taskLookup = map (toTask . fst) . filter isOnCore . M.toList $ tm
    where
        -- Cleanup
        isOnCore (_, coreId) = coreId == cId c
        toTask task = fromMaybe (error "Task not in task lookup") $ M.lookup task taskLookup

basicNetworkLatency :: Task -> Int -> Platform -> Float
basicNetworkLatency t hops (fs, lb, pd, sf) = (flits * flitBandwidth) + processingDelay
    where
        flits = fi . ceiling $ ((fi . cSize . tCommunication) t /  fi fs)
        flitBandwidth = fi fs / fi lb
        processingDelay = fi hops * (pd / sf)
        fi = fromIntegral

-- Should be returning EndToEndResponseTimes
communicationAnalysis :: Platform -> Application -> M.Map Task TrafficFlow
communicationAnalysis p@(_, _, _, sf) a@(cs, ts, tm, cm) = trafficFlows
    where
        coreLookup = M.fromList . map (\c -> (cId c, c)) $ cs
        taskLookup = M.fromList . map (\t -> (tId t, t)) $ ts
        idLookup = (taskLookup, coreLookup)
        responseTimes = flattenMap . map (\c -> responseTimeAnalysis (tasksOnCore c a taskLookup) c sf) $ cs
        trafficFlows = lookupTasks taskLookup . M.fromList . map (\t -> (tId t, route t a)) $ ts
        basicLatencies = map (\(t, tf) -> basicNetworkLatency t (length tf) p) . M.toList $ trafficFlows
        -- basicLatencies = (M.fromList . map (\t -> (tId t, basicCommunicationLatency t p (trafficFlows))
        tss = ascendingPriority ts
