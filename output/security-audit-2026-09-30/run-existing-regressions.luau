-- Existing regression suites use disposable engines and injected in-memory stores.
local root=game.ServerScriptService.MarketReign
local report={Suites={},NamedScenarios=0,IndividualAssertions=0,Failures=0}
for _,name in ipairs({"PermanentShopTests","WorldTests","TradeLimitsTests","TradeAmendmentTests","LeaderboardTests","FundedTests","DepletionTests","ProgressionTests","StatsTests","MarketTests"})do
 local start=os.clock()
 local ok,result=pcall(function()local suite=require(root[name]);return type(suite)=="function" and suite() or suite.Run()end)
 local s={Name=name,Ok=ok,Seconds=os.clock()-start,Result=result}
 if ok then
  if result.Cases then
   report.IndividualAssertions+=result.Cases
   if not result.Passed then report.Failures+=1 end
  elseif result.Total then
   report.NamedScenarios+=result.Total
   report.Failures+=result.Total-result.Passed
  else for _,row in ipairs(result)do report.NamedScenarios+=1;if not row.Passed then report.Failures+=1 end end end
 else report.Failures+=1 end
 table.insert(report.Suites,s)
end
return game:GetService("HttpService"):JSONEncode(report)
