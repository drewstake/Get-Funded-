script={Parent={ChartViewport="./ChartViewport",ChartTools="./ChartTools"}}
local ok1,r1=pcall(require("./ChartViewportTests")) print("viewport",ok1,type(r1)=="table" and r1.Cases or r1)
local ok2,r2=pcall(require("./ChartToolsTests")) print("tools",ok2,type(r2)=="table" and r2.Cases or r2)
