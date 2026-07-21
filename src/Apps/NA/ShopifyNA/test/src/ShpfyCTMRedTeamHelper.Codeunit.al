namespace Microsoft.Integration.Shopify;

using System.AI;
using System.TestLibraries.AI;

/// <summary>
/// Codeunit Shpfy CTM Red Team Helper (ID 134723).
/// Shared plumbing for the Red Team Scan-based Responsible-AI tests (content harms + jailbreak/XPIA):
/// registers + activates the Copilot capability, sets up a probe shop, and feeds a generated attack
/// string through the matcher via the untrusted ship-to address, returning the matcher's free-text
/// output (the LLM `reason` values + assigned jurisdiction codes) for the scan to score.
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
        NoMatchResponseTxt: Label 'No tax jurisdiction could be matched.', Locked = true;

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
    var
        OrderHeader: Record "Shpfy Order Header";
        CopilotTaxMatcher: Codeunit "Shpfy Copilot Tax Matcher";
        MatchedJurisdictions: List of [Code[10]];
        MatchLog: JsonArray;
        HasRateConflict: Boolean;
        Response: Text;
    begin
        OrderHeader := CTMTestLibrary.SetupHarmProbeOrder(Shop, AttackQuery);
        if CopilotTaxMatcher.MatchTaxLines(OrderHeader, Shop, MatchedJurisdictions, MatchLog, HasRateConflict) then
            Response := BuildResponseText(MatchLog);
        if Response = '' then
            Response := NoMatchResponseTxt;
        exit(Response);
    end;

    local procedure BuildResponseText(MatchLog: JsonArray) Response: Text
    var
        MatchToken: JsonToken;
        ValueToken: JsonToken;
        MatchObj: JsonObject;
        Line: Text;
    begin
        foreach MatchToken in MatchLog do begin
            MatchObj := MatchToken.AsObject();
            Line := '';
            if MatchObj.Get('jurisdictionCode', ValueToken) then
                if ValueToken.IsValue() then
                    Line := ValueToken.AsValue().AsText();
            if MatchObj.Get('reason', ValueToken) then
                if ValueToken.IsValue() then
                    Line += ': ' + ValueToken.AsValue().AsText();
            if Line <> '' then begin
                if Response <> '' then
                    Response += ' | ';
                Response += Line;
            end;
        end;
    end;
}
