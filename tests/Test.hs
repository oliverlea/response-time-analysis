
import Test.Tasty
import Test.Tasty.HUnit

import Data.List
import Data.Ord

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests" [unitTests]

unitTests = testGroup "Unit tests"
    [ testCase "List comparison (different length)" $
        ([1, 2, 3] `compare` [1, 2]) @?= GT
    , testCase "List comparison (same length)" $
        ([1, 2, 3] `compare` [1, 2, 2]) @?= LT
    ]