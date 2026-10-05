-- Edit mode only. Load local source without opening a saved exchange or player profile.
assert(not game:GetService('RunService'):IsRunning(),'Stop Play before installing source')
local Http=game:GetService('HttpService');local prior=Http.HttpEnabled;Http.HttpEnabled=true
local ok,result=xpcall(function()
 local manifest=Http:JSONDecode(Http:GetAsync('http://127.0.0.1:8771/output/single-account-20261001/source-manifest.json'))
 local count=0
 for _,item in ipairs(manifest) do
  local root=game
  for part in item.Parent:gmatch('[^.]+') do root=assert(root:FindFirstChild(part),part) end
  local obj=root:FindFirstChild(item.Name)
  if not obj then obj=Instance.new(item.Class);obj.Name=item.Name;obj.Parent=root end
  obj.Source=Http:GetAsync('http://127.0.0.1:8771/src/'..item.File)
  count+=1
 end
 for _,name in ipairs({'FundedTests','DepletionTests','ProgressionTests','ReearnTests','PermanentShopTests','StatsTests','LeaderboardTests'}) do
  local old=game.ServerScriptService.MarketReign:FindFirstChild(name);if old then old:Destroy() end
 end
 return count
end,debug.traceback)
Http.HttpEnabled=prior
assert(ok,result)
return {Scripts=count or result,StorageAccessed=false}
