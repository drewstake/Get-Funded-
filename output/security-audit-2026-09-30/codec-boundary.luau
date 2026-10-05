-- Disposable codec boundary test, no DataStore or live market access.
local CP=require(game.ServerScriptService.MarketReign.WorldCheckpoint)
local H=game:GetService("HttpService")
local record=CP.Encode({AuditPadding=string.rep("x",32000001)})
local ok,err=pcall(CP.Decode,record)
return H:JSONEncode({RawBytes=record.RawBytes,EncodedBytes=#H:JSONEncode(record),WithinSaveByteLimit=#H:JSONEncode(record)<3500000,DecoderAccepted=ok,Error=ok and "" or tostring(err)})

