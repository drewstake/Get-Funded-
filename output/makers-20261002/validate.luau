-- Disposable engines and fake stores only; no Studio or network access.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local process=require("@lune/process")
local R=require("../security-fix-verification-2026-09-30/lune-harness/roblox")
local shared={MarketConfig=true,ProgressionConfig=true,ProgressionRules=true,TradeProtection=true,ContractLimits=true}
for _,file in ipairs(fs.readDir("src")) do
 local name=file:match("^(.-)%.luau$")
 if name then R.module(shared[name] and R.Shared or R.Server,name,"src/"..file) end
end
for _,name in ipairs({"MarketConfig","Participants","WorldCheckpoint","WorldTests"}) do luau.compile(fs.readFile("src/"..name..".luau")) end
local report={Passed=0,Total=0,AdditionalAssertions=0,Suites={}}
for _,name in ipairs({"WorldTests","MarketTests","SingleAccountTests","TradeLimitsTests","TradeAmendmentTests"}) do
 local started=os.clock()
 local ok,result=pcall(function()
  local module=R.require(R.Server[name])
  return type(module)=="function" and module() or module.Run()
 end)
 local rows
 if not ok then rows={{Name=name,Passed=false,Detail=tostring(result)}}
 elseif result.Cases then
  report.AdditionalAssertions+=result.Cases
  rows={{Name=name,Passed=result.Passed,Detail=result.Cases.." assertions"}}
 else rows=result.Results or result end
 local suite={Name=name,Seconds=os.clock()-started,Results=rows,Passed=0,Total=#rows}
 for _,row in ipairs(rows) do
  report.Total+=1
  if row.Passed then suite.Passed+=1;report.Passed+=1 else print("FAIL "..name..": "..row.Name..": "..tostring(row.Detail)) end
 end
 table.insert(report.Suites,suite)
 print(name..": "..suite.Passed.."/"..suite.Total.." passed")
end
fs.writeFile("output/makers-20261002/validation.json",R.JSONEncode(report))
print("TOTAL "..report.Passed.."/"..report.Total)
if report.Passed~=report.Total then process.exit(1) end
