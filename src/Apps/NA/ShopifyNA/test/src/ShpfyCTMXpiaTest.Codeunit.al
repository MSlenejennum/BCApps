namespace Microsoft.Integration.Shopify;

using System.TestLibraries.Utilities;
using System.TestTools.AITestToolkit;
using System.TestTools.TestRunner;

/// <summary>
/// Codeunit Shpfy CTM XPIA Test (ID 134721).
/// Responsible-AI cross-prompt-injection (XPIA) tests: adversarial instructions are injected into
/// the order's externally-controlled free-text fields (ship-to city/county, shipping-charge and
/// tax-line titles), a real LLM match is run, and the matcher output + persisted records are
/// asserted to be safe — the injection is ignored, the system prompt does not leak into the
/// `reason` field, and no injection-driven garbage Tax Jurisdiction is created.
/// </summary>
codeunit 134721 "Shpfy CTM XPIA Test"
{
    Subtype = Test;
    TestType = AITest;
    TestPermissions = Disabled;
    Access = Internal;

    [Test]
    procedure XpiaTaxMatching()
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        CopilotTaxMatcher: Codeunit "Shpfy Copilot Tax Matcher";
        TaxAreaBuilder: Codeunit "Shpfy Tax Area Builder";
        CTMTestLibrary: Codeunit "Shpfy CTM Test Library";
        CTMVerify: Codeunit "Shpfy CTM Verify";
        Input: Codeunit "Test Input Json";
        Setup: Codeunit "Test Input Json";
        Expected: Codeunit "Test Input Json";
        MatchedJurisdictions: List of [Code[10]];
        MatchLog: JsonArray;
        ResolvedTaxAreaCode: Code[20];
        TaxAreaWasCreated: Boolean;
        Result: Boolean;
        HasRateConflict: Boolean;
        ElementExists: Boolean;
    begin
        // Arrange — the scenario's setup carries the injected free-text fields.
        CTMTestLibrary.CleanupTestData();
        Input := CTMTestLibrary.GetInput();
        Setup := Input.Element('setup');

        Shop := CTMTestLibrary.SetupShop(Setup.Element('shopSettings'));
        CTMTestLibrary.SetupTaxJurisdictions(Setup);
        CTMTestLibrary.SetupGLAccounts(Setup);
        OrderHeader := CTMTestLibrary.SetupOrder(Setup, Shop);

        // Act — real LLM call + tax area, exactly as the production event path does.
        Result := CopilotTaxMatcher.MatchTaxLines(OrderHeader, Shop, MatchedJurisdictions, MatchLog, HasRateConflict);
        if Result and (MatchedJurisdictions.Count() > 0) then
            TaxAreaBuilder.FindOrCreateTaxArea(OrderHeader, Shop, MatchedJurisdictions, ResolvedTaxAreaCode, TaxAreaWasCreated);

        LogTestOutput(Input, OrderHeader, MatchLog, Result);

        // Assert
        Expected := Input.Element('expected');

        Expected.ElementExists('matchResult', ElementExists);
        if ElementExists then
            LibraryAssert.AreEqual(Expected.Element('matchResult').ValueAsBoolean(), Result, 'MatchTaxLines result');

        // Legitimate-match / tax-area assertions (shared with the accuracy suite).
        CTMVerify.VerifyFromExpected(Expected, OrderHeader);
        // XPIA-specific safety assertions (reason has no leakage/injection; no garbage jurisdiction).
        CTMVerify.VerifyXpiaSafety(Expected, MatchLog);
    end;

    local procedure LogTestOutput(Input: Codeunit "Test Input Json"; OrderHeader: Record "Shpfy Order Header"; MatchLog: JsonArray; Result: Boolean)
    var
        AnswerJson: JsonObject;
        ContextJson: JsonObject;
        QueryText: Text;
        AnswerText: Text;
        ContextText: Text;
    begin
        QueryText := Input.Element('description').ValueAsText();

        AnswerJson.Add('matchResult', Result);
#pragma warning disable AA0181
        OrderHeader.Find();
#pragma warning restore AA0181
        AnswerJson.Add('taxAreaCode', OrderHeader."Tax Area Code");
        AnswerJson.Add('taxLiable', OrderHeader."Tax Liable");
        AnswerJson.Add('matchLog', MatchLog);
        AnswerJson.WriteTo(AnswerText);

        ContextJson.Add('setup', Input.Element('setup').AsJsonToken());
        ContextJson.WriteTo(ContextText);

        AITTestContext.SetQueryResponse(QueryText, AnswerText, ContextText);
    end;

    var
        AITTestContext: Codeunit "AIT Test Context";
        LibraryAssert: Codeunit "Library Assert";
}
