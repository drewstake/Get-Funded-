-- Usage: lune run run.luau <srcdir> <script.luau|suite:Name,...> [out.json]
local process=require("@lune/process")
local fs=require("@lune/fs")
local R=require("../security-fix-verification-2026-09-30/lune-harness/roblox")
local src=process.args[1] or "/home/claude/gf/src"
local target=process.args[2] or "suites"
local shared={ProgressionRules=1,ContractLimits=1,MarketConfig=1,ProgressionConfig=1,TradeProtection=1,StatsView=1,StatsPieces=1,StatsCharts=1,MarketClient=1,TerminalUI=1,UIFeedback=1,
 ChartView=1,ChartViewport=1,ChartTools=1,ChartPaintPool=1,LeaderboardClient=1,LeaderboardView=1,DemoMarket=1,
 ChartToolsTests=1,ChartViewportTests=1,ChartPaintPoolTests=1}
for _,entry in ipairs(fs.readDir(src)) do
 local name=entry:match("^(.-)%.luau$")
 if name and not name:find("%.server$") and not name:find("%.client$") then
  R.module(shared[name] and R.Shared or R.Server,name,src.."/"..entry)
 end
end
R.game:GetService("UserService").GetUserInfosByUserIdsAsync=function()return {}end
local HttpService=R.game:GetService("HttpService")
local function out(result)
 local text=type(result)=="string" and result or HttpService:JSONEncode(result)
 if process.args[3] then fs.writeFile(process.args[3],text) end
 print(text)
end
if target:match("%.luau$") then
 -- Audit/verification scripts expect the Roblox globals.
 local luau=require("@lune/luau")
 local chunk=luau.load(fs.readFile(target),{debugName=target,environment={game=R.game,require=R.require,Enum=R.Enum,task=require("@lune/task"),warn=R.warn,typeof=R.typeof,debug=setmetatable({profilebegin=function() end,profileend=function() end},{__index=debug})}})
 local ok,result=pcall(chunk)
 if not ok then print("SCRIPT ERROR: "..tostring(result)) process.exit(1) end
 out(result)
 return
end
local names={}
local list=target:match("^suites:(.+)$")
if list then for n in list:gmatch("[^,]+") do table.insert(names,n) end
else names={"PermanentShopTests","WorldTests","TradeLimitsTests","TradeAmendmentTests","LeaderboardTests","FundedTests","DepletionTests","ProgressionTests","StatsTests","MarketTests","ReearnTests"} end
local report={Suites={},NamedScenarios=0,IndividualAssertions=0,Failures=0}
for _,name in ipairs(names) do
 local started=os.clock()
 local ref=R.Server[name] or R.Shared[name]
 local ok,result=pcall(function() assert(ref,"Missing suite "..name) local suite=R.require(ref) return type(suite)=="function" and suite() or suite.Run() end)
 local s={Name=name,Ok=ok,Seconds=os.clock()-started,Failed={}}
 if ok then
  if result.Cases then report.IndividualAssertions+=result.Cases s.Cases=result.Cases s.Passed=result.Passed
   if not result.Passed then report.Failures+=1 table.insert(s.Failed,tostring(result.Error or result.Message or "failed")) end
  elseif result.Total then report.NamedScenarios+=result.Total s.Total=result.Total s.PassedCount=result.Passed report.Failures+=result.Total-result.Passed
   for _,row in ipairs(result.Results or result.Rows or {}) do if not row.Passed then table.insert(s.Failed,row.Name..": "..tostring(row.Detail or row.Error)) end end
  else
   s.Total=#result s.PassedCount=0
   for _,row in ipairs(result) do report.NamedScenarios+=1
    if row.Passed then s.PassedCount+=1 else report.Failures+=1 table.insert(s.Failed,tostring(row.Name)..": "..tostring(row.Detail)) end
   end
   s.Names={} for _,row in ipairs(result) do table.insert(s.Names,(row.Passed and "PASS " or "FAIL ")..tostring(row.Name)) end
  end
 else report.Failures+=1 table.insert(s.Failed,tostring(result)) end
 table.insert(report.Suites,s)
end
report.Warnings=R.warnings
local text=HttpService:JSONEncode(report)
if process.args[3] then fs.writeFile(process.args[3],text) end
for _,s in ipairs(report.Suites) do
 print(string.format("%-22s %s  %.2fs  %s",s.Name,(s.Ok and #s.Failed==0) and "OK  " or "FAIL",s.Seconds,
  s.Cases and ("assertions="..s.Cases) or ("scenarios="..tostring(s.PassedCount).."/"..tostring(s.Total))))
 for _,f in ipairs(s.Failed) do print("    ! "..f) end
end
print(string.format("NamedScenarios=%d IndividualAssertions=%d Failures=%d",report.NamedScenarios,report.IndividualAssertions,report.Failures))
