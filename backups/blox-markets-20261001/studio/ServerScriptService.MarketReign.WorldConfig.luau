-- Server-only storage and ownership settings. Never copy a live checkpoint into ReplicatedStorage.
return {
 Enabled=true,
 StoreName="MarketReign_Continuous_v1",
 WorldKey="primary-exchange",
 LeaseSeconds=90,
 SafetySeconds=15,
 SaveSeconds=15,
 RetrySeconds=5,
 MaxEncodedBytes=3500000,
 -- Unpublished Studio files cannot use Roblox persistence. Keep an explicitly labelled local sandbox.
 AllowUnsavedStudio=true,
 StudioReplaySeed=0, -- A positive value replays a NEW Studio world only; live servers always seed privately.
}