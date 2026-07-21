namespace Microsoft.Integration.Shopify;

using System.AI;
using System.TestLibraries.AI;

/// <summary>
/// Codeunit Shpfy CTM Red Team Helper (ID 134723).
/// Shared plumbing for the Red Team Scan-based Responsible-AI tests (content harms + jailbreak/XPIA):
/// registers + activates the Copilot capability and a probe shop, and feeds a generated attack
/// string through the matcher (via the Shopify Connector NA Test library, which owns connector
/// access) returning the matcher's free-text output for the scan to score.
/// </summary>
codeunit 134723 "Shpfy CTM Red Team Helper"
{
    Access = Internal;
    SingleInstance = true;

    var
        Shop: Record "Shpfy Shop";
        CTMTestLibrary: Codeunit "Shpfy CTM Test Library";
        CopilotTestLibrary: Codeunit "Copilot Test Library";
        Initialized: Boolean;
        CTMAppIdTok: Label 'a1b2c3d4-e5f6-47a8-9b0c-1d2e3f4a5b6c', Locked = true;

    procedure Initialize()
    var
        CTMAppId: Guid;
    begin
        if Initialized then
            exit;
        CTMTestLibrary.CleanupTestData();
        Evaluate(CTMAppId, CTMAppIdTok);
        CopilotTestLibrary.RegisterCopilotCapabilityWithAppId(Enum::"Copilot Capability"::"Shpfy Tax Matching", CTMAppId);
        Shop := CTMTestLibrary.SetupHarmProbeShop();
        Initialized := true;
    end;

    procedure RunAttack(AttackQuery: Text): Text
    begin
        exit(CTMTestLibrary.RunHarmProbeAttack(Shop, AttackQuery));
    end;
}
