-- Run in Studio EDIT context after installing source changes. Saves only native GUI objects.
-- Clone modules to avoid Studio's require cache when regenerating the preview after edits.
local shared=game.ReplicatedStorage.MarketReign:Clone()
shared.Name="PreviewSharedBuild" shared.Parent=game.ReplicatedStorage
local server=game.ServerScriptService.MarketReign:Clone()
server.Name="PreviewEngineBuild" server.MarketServer.Enabled=false server.Parent=game.ServerScriptService
local ok,result=pcall(function()
 local Config=require(shared.MarketConfig)
 local Engine=require(server.MarketEngine)
 local Participants=require(server.Participants)
 local engine=Engine.new(Config,Config.Seed~=0 and Config.Seed or 73521)
 local population=Participants.new(engine)
 for _=1,math.floor(Config.WarmupSeconds/Config.StepSeconds) do population:Step() end
 -- The saved preview shows the starter funded account new players begin with.
 local ladder=require(shared.ProgressionConfig);local starter=ladder.Tiers[1]
 local funded=require(server.FundedAccounts).new(engine,ladder,Config)
 funded:Start("preview") funded:Flag("preview","TutorialDone")
 local owner=funded:Owner("preview")
 local snapshot=engine:Snapshot(owner,"ES","1m",true)
 snapshot.CandlesBySeries={}
 for _,key in ipairs(Config.ContractOrder) do
  for _,tf in ipairs(Config.Timeframes) do snapshot.CandlesBySeries[key..":"..tf[1]]=engine:Snapshot(owner,key,tf[1],true).Candles end
 end
 local controller=require(shared.TerminalUI).Mount(game.StarterGui.MarketReign,{Preview=true,PreviewData=snapshot,PortfolioData=funded:View("preview")})
 local count=0
 for _,object in ipairs(controller.Root.Canvas.Chart.CandlestickPlot:GetDescendants()) do if object.Name=="Candle" and object.Visible then count+=1 end end
 assert(count>0,"Preview requires executed trades")
 assert(not controller.Root:FindFirstChild("Waiting",true),"Preview unexpectedly empty")
 return {Candles=count,Seed=engine.Seed,Executions=engine.NextTrade,Audit=engine:Audit(),Status=controller.Root:GetAttribute("ExchangeStatus")}
end)
shared:Destroy() server:Destroy()
if not ok then error(result) end
return result
