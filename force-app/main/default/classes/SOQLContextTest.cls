@IsTest
private class SOQLContextTest {
    static final Schema.SObjectType MockClaimType = Schema.RKUX_Mock_Claim__c.SObjectType;
    static SOQLContext context;

    @IsTest
    private static void TestQueryRules() {
        context = SOQLContext.newSystemMode()
            .defineRuleSet('Mock Claim Search Rules')
                .fromClauseTarget(Schema.RKUX_Mock_Claim__c.SObjectType)
                .whereClauseRequired()
                //.metadataRule('Test_Match_3')
                .subRules()
                    .matchAny()
                    // Alternative #1: Match exactly on field Mock_Id__c:
                    .metadataRule('Test_Match_ID')
                    // Alternative #2 Include any 3 of the designated match terms (listed below):
                    .metadataRule('Test_Match_3')
            .context();
        
        // Restricted_Search__mdt metadata "Test_Match_3" for Schema.RKUX_Mock_Claim__c is configured as follows:
        //
        // Match Any 3 (Exact "=" Matches Only) Of:
        //   Mock_Claimant_Last_Name__c [Required Match]
        //   Cause__c
        //   Claimant_City__c
        //   Date_Claimant_Born__c
        //   Claimant_First_Name__c
        // 
        // Allow Extra "Freestyle" AND's On:
        //   Date_Hired__c
        //   Claimant_Country__c

        //SObject foo = Database.query('SELECT Id FROM Contact WHERE Foo > 1');
        //String soqlTest = SOQLContext.newStrictMode().getQuery(
        //        'SELECT Name, FIELDSET(Contact_FS_1), GenderIdentity FROM Contact', null, AllNullBinds, null);
        //Assert.areEqual('Foo', soqlTest);

        //String soqlTest = context.getQuery(
        //        'SELECT * FROM ' + MockClaimType + ' WHERE Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ?', null, AllNullBinds, null);
        //Assert.areEqual('Foo', soqlTest);

        //Integer nmeta = SOQLContext.newSystemMode().query('SELECT * FROM Restricted_Search__mdt WHERE Target__c = ? AND Object_Type__c = ?', new Object[]{ 'LWC - Strict Custom Lookup', '' + MockClaimType }).size();
        //Assert.areEqual(2, nmeta);

        // Success: meets basic restriction requirements, no more or less:
        String soql = assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ?', 
            new Object[]{ 'Coolio', 'Compton', Date.newInstance(1980, 4, 4) });

        Assert.areEqual(
            'SELECT Id FROM ' + MockClaimType + ' WHERE Mock_Claimant_Last_Name__c = \'Coolio\' AND Claimant_City__c = \'Compton\' AND Date_Claimant_Born__c = 1980-04-03', 
            soql);

        // Violation: Query not allowed on Contact; must be RKUX_Mock_Claim__c:
        assertFullQueryViolation('SELECT Id FROM Contact Where Id != null');

        // Violation: Query requires a WHERE clause:
        assertFullQueryViolation('SELECT Id FROM ' + MockClaimType);

        // Success: Query satisfies alternative #1 metadata rule:
        assertFullQuerySuccess('FROM ' + MockClaimType + ' WHERE Mock_Id__c = "123"');

        // Success: has the 3 required match terms, AND is the top-level condition, and the superfluous groupings do not confuse the rules engine:
        assertSuccess('(Mock_Claimant_Last_Name__c = ? AND (Claimant_City__c = ? AND Date_Claimant_Born__c = ?))');

        // Success: extra 4th match term (AND) is OK:
        assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Cause__c = ?');

        // Success: extra freestyle term is allowed (AND):
        assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Date_Hired__c = ?');

        // Success: 1st alternate rule (Match Any) passes on exact match on ID:
        assertSuccess('Mock_Id__c = ?');

        // Success: freestyle terms can be in nested OR and NOT conditions, as long as they're all under a top-level AND:
        //assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND (Date_Hired__c = ? OR NOT Claimant_Country__c = ?)');

        // Violation: match term not allowed in OR condition:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND (Claimant_City__c = ? OR Date_Claimant_Born__c = ?)');

        // Violation: top level of WHERE condition cannot be OR:
        assertViolation('Mock_Claimant_Last_Name__c = ? OR Claimant_City__c = ? OR Date_Claimant_Born__c = ?');

        // Violation: match term not allowed in NOT condition:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND NOT Date_Claimant_Born__c = ?');

        // Violation: required match term Mock_Claimant_Last_Name__c is missing:
        assertViolation('Cause__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ?');

        // Violation: only 2 match terms; does not meet minimum of 3:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ?');

        // Violation: match term uses disallowed ">" operator:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Date_Hired__c > ?');

        // Violation: match term uses disallowed "LIKE" operator:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Cause LIKE "%"');

        // Violation: match term uses disallowed "contains" operator:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Cause contains "foo"');

        // Violation: unresolved named bind parameter ":foo":
        assertViolation('Mock_Claimant_Last_Name__c = :foo AND Claimant_City__c = ? AND Date_Claimant_Born__c = ?');

         // Failure: Invalid syntax:
         //assertFailure('foo bar baz');
    }

    static Object[] AllNullBinds = new Object[]{ null, null, null, null, null, null, null, null, null, null };

    static String assertSuccess(String whereClause) {
        return assertSuccess(whereClause, AllNullBinds);
    }

    static String assertSuccess(String whereClause, Object[] anonBinds) {
        String soql;
        try {
            soql = context.getQuery(
                'FROM ' + MockClaimType + ' WHERE ' + whereClause, null, anonBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            Assert.fail('Unexpected Rule Violation: ' + err.getMessage());
        }
        return soql;
    }

    static String assertFullQuerySuccess(String fullQuery) {
        String soql;
        try {
            soql = context.getQuery(fullQuery, null, AllNullBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            Assert.fail('Unexpected Rule Violation: ' + err.getMessage());
        }
        return soql;
    }

    static void assertViolation(String whereClause) {
        assertViolation(whereClause, AllNullBinds);
    }

    static void assertViolation(String whereClause, Object[] anonBinds) {
        Boolean gotErr = false;
        try {
            context.getQuery(
                'FROM ' + MockClaimType + ' WHERE ' + whereClause, null,anonBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            gotErr = true;
        }
        Assert.isTrue(gotErr, 'Missed Rule Violation on: ' + whereClause);
    }

    static void assertFullQueryViolation(String fullQuery) {
        Boolean gotErr = false;
        try {
            context.getQuery(fullQuery, null, AllNullBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            gotErr = true;
        }
        Assert.isTrue(gotErr, 'Missed Rule Violation on: ' + fullQuery);
    }

    // Rule Violation on [Patient Lookup]: WHERE clause is required
    // Rule Violation on [Patient Lookup][Match Any Of 2][Last Violation][Match LastName, Birth, SSN4]: Expected at least 3 qualifying match terms; got 2
}