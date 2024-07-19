@IsTest
private class SOQLContextTest {
    static final Schema.SObjectType MockClaimType = 
        Schema.RKUX_Mock_Claim__c.SObjectType;
    static SOQLContext[] TestContexts = new SOQLContext[]{};
    static Integer TestIndex = 0;

    @IsTest
    private static void TestQueryRules() {
        TestContexts.add(
            // Metadata-driven search terms rules:
            SOQLContext.newSystemMode()
                .defineRuleSet('Metadata Search Rules')
                    .fromClauseTarget(Schema.RKUX_Mock_Claim__c.SObjectType)
                    .whereClauseRequired()
                    //.metadataRule('Test_Match_3')
                    .subRules()
                        .matchAny()
                        // Alternative #1: Match exactly on field Mock_Id__c:
                        .metadataRule('Test_Match_ID')
                        // Alternative #2 Include any 3 of the designated 
                        // match terms (enumerated in "inline" rules below):
                        .metadataRule('Test_Match_3')
                .context()
        );

        TestContexts.add(
            // Inline-defined search terms equivalent of the above metadata-driven 
            // rules - which should yield the exact same results on the following 
            // assertions:
            SOQLContext.newSystemMode()
                .defineRuleSet('Inline Search Rules')
                    .fromClauseTarget(Schema.RKUX_Mock_Claim__c.SObjectType)
                    .whereClauseRequired()
                    .subRules()
                        .matchAny()
                        // Alternative #1: Query condition must match exactly on 
                        // field Mock_Id__c:
                        .startSearchTerms('Match ID')
                            .minimumMatches(1)
                            .matchTerm('Mock_Id__c')
                        .endSearchTerms()
                        // Alternative #2 Query must include at least 3 of the 
                        // following enumerated "match terms"; Last Name is 
                        // required to be one of the terms.
                        .startSearchTerms('Match 3')
                            .minimumMatches(3)
                            .requiredMatchTerm('Mock_Claimant_Last_Name__c')
                            .matchTerm('Cause__c')
                            .matchTerm('Claimant_City__c')
                            .matchTerm('Date_Claimant_Born__c')
                            .matchTerm('Claimant_First_Name__c')
                            .freestyleTerm('Date_Hired__c')
                            .freestyleTerm('Claimant_Country__c')
                        .endSearchTerms()
                .context()
        );

        //SObject foo = Database.query('SELECT Id FROM Contact WHERE Foo');
        //String soqlTest = SOQLContext.newStrictMode().getQuery(
        //    'SELECT Name, FIELDSET(Contact_FS_1), GenderIdentity' + 
        //    ' FROM Contact WHERE LastName', null, AllNullBinds, null);
        //Assert.areEqual('Foo', soqlTest);

        //String soqlTest = context.getQuery(
        //    'SELECT * FROM ' + MockClaimType + 
        //    ' WHERE Mock_Claimant_Last_Name__c = ?' + 
        //            ' AND Claimant_City__c = ?' + 
        //            ' AND Date_Claimant_Born__c = ?', null, AllNullBinds, null);
        //Assert.areEqual('Foo', soqlTest);

        //Integer nmeta = SOQLContext.newSystemMode().query(
        //    'SELECT * FROM Restricted_Search__mdt' + 
        //    ' WHERE Target__c = ?' + 
        //        ' AND Object_Type__c = ?', 
        //    new Object[]{ 'LWC - Strict Custom Lookup', '' + MockClaimType })
        //    .size();
        //Assert.areEqual(2, nmeta);

        do {
            // Success: meets basic restriction requirements, no more or less:
            SOQLParser.SOQL soql = assertSuccess(
                'Mock_Claimant_Last_Name__c = ?' + 
                    ' AND Claimant_City__c = ?' + 
                    ' AND Date_Claimant_Born__c = ?', 
                new Object[]{ 'Coolio', 'Compton', Date.newInstance(1980, 4, 4) });

            String expectedVanillaSOQL = 
                'SELECT Id FROM ' + MockClaimType + 
                ' WHERE Mock_Claimant_Last_Name__c = \'Coolio\'' + 
                    ' AND Claimant_City__c = \'Compton\'' + 
                    ' AND Date_Claimant_Born__c = 1980-04-03';
            Assert.areEqual(expectedVanillaSOQL, soql.ser());
            // Assert again to verify there are no unexpected side-effects from 
            // the 1st serialization:
            Assert.areEqual(expectedVanillaSOQL, soql.ser());
            
            // Extract the parsed & validated WHERE condition from above, and 
            // remix it into a new query that WOULD have violated our original 
            // rules (because of the top-level OR), but passes under this new 
            // system context!:
            SOQLParser.SOQL soqlRemix = 
                SOQLContext.newSystemMode()
                    .getSOQL(
                        'FROM ' + soql.getFromTarget() + 
                        ' WHERE Mock_Id__c = "abc" OR (' + 
                            soql.getWhereCondition().ser() + ')');
            Assert.areEqual(
                'SELECT Id FROM ' + MockClaimType + 
                ' WHERE Mock_Id__c = \'abc\'' + 
                    ' OR (Mock_Claimant_Last_Name__c = \'Coolio\'' + 
                        ' AND Claimant_City__c = \'Compton\'' + 
                        ' AND Date_Claimant_Born__c = 1980-04-03)', 
                soqlRemix.ser());
            // And finally, assert that this remixed query fails the rule set
            // under our original context:
            assertFullQueryViolation(soqlRemix.ser());

            // Violation: Query not allowed on Contact; must be 
            // RKUX_Mock_Claim__c:
            assertFullQueryViolation('SELECT Id FROM Contact Where Id != null');

            // Violation: Query requires a WHERE clause:
            assertFullQueryViolation('SELECT Id FROM ' + MockClaimType);

            // Success: Query satisfies alternative #1 metadata rule:
            assertFullQuerySuccess(
                'FROM ' + MockClaimType + 
                ' WHERE Mock_Id__c = "123"');

            // Success: has the 3 required match terms, AND is the top-level 
            // condition, and the superfluous groupings do not confuse the 
            // rules engine:
            assertSuccess('(Mock_Claimant_Last_Name__c = ?' + 
                ' AND (Claimant_City__c = ? AND Date_Claimant_Born__c = ?))');

            // Success: extra 4th match term (AND) is OK:
            assertSuccess('Mock_Claimant_Last_Name__c = ?' + 
                ' AND Claimant_City__c = ?' + 
                ' AND Date_Claimant_Born__c = ?' + 
                ' AND Cause__c = ?');

            // Success: extra freestyle term is allowed (AND):
            assertSuccess('Mock_Claimant_Last_Name__c = ?' + 
                ' AND Claimant_City__c = ?' + 
                ' AND Date_Claimant_Born__c = ?' + 
                ' AND Date_Hired__c = ?');

            // Success: 1st alternate rule (Match Any) passes on exact match 
            // on ID:
            assertSuccess('Mock_Id__c = ?');

            // Success: freestyle terms can be in nested OR and NOT conditions,
            // as long as they're all under a top-level AND:
            //assertSuccess('Mock_Claimant_Last_Name__c = ?' + 
            //    ' AND Claimant_City__c = ?' + 
            //    ' AND Date_Claimant_Born__c = ?' + 
            //    ' AND (Date_Hired__c = ?' + 
            //    ' OR NOT Claimant_Country__c = ?)');

            // Violation: match term not allowed in OR condition:
            assertViolation('Mock_Claimant_Last_Name__c = ?' + 
                ' AND (Claimant_City__c = ?' + 
                ' OR Date_Claimant_Born__c = ?)');

            // Violation: top level of WHERE condition cannot be OR:
            assertViolation('Mock_Claimant_Last_Name__c = ?' + 
                ' OR Claimant_City__c = ?' + 
                ' OR Date_Claimant_Born__c = ?');

            // Violation: match term not allowed in NOT condition:
            assertViolation('Mock_Claimant_Last_Name__c = ?' + 
                ' AND Claimant_City__c = ?' + 
                ' AND NOT Date_Claimant_Born__c = ?');

            // Violation: required match term Mock_Claimant_Last_Name__c 
            // is missing:
            assertViolation('Cause__c = ?' + 
                ' AND Claimant_City__c = ?' + 
                ' AND Date_Claimant_Born__c = ?');

            // Violation: only 2 match terms; does not meet minimum of 3:
            assertViolation('Mock_Claimant_Last_Name__c = ?' + 
                ' AND Claimant_City__c = ?');

            // Violation: match term uses disallowed ">" operator:
            assertViolation('Mock_Claimant_Last_Name__c = ?' + 
                ' AND Claimant_City__c = ?' + 
                ' AND Date_Claimant_Born__c = ?' + 
                ' AND Date_Hired__c > ?');

            // Violation: match term uses disallowed "LIKE" operator:
            assertViolation('Mock_Claimant_Last_Name__c = ?' + 
                ' AND Claimant_City__c = ?' + 
                ' AND Date_Claimant_Born__c = ?' + 
                ' AND Cause LIKE "%"');

            // Violation: match term uses disallowed "contains" operator:
            assertViolation('Mock_Claimant_Last_Name__c = ?' + 
                ' AND Claimant_City__c = ?' + 
                ' AND Date_Claimant_Born__c = ?' + 
                ' AND Cause contains "foo"');

            // Violation: unresolved named bind parameter ":foo":
            assertViolation('Mock_Claimant_Last_Name__c = :foo' + 
                ' AND Claimant_City__c = ?' + 
                ' AND Date_Claimant_Born__c = ?');

            // Failure: Invalid syntax:
            //assertFailure('foo bar baz');
        } while (++TestIndex < TestContexts.size());
    }

    static Object[] AllNullBinds = new Object[]{ 
        null, null, null, null, null, null, null, null, null, null };

    static SOQLParser.SOQL assertSuccess(String whereClause) {
        return assertSuccess(whereClause, AllNullBinds);
    }

    static SOQLParser.SOQL assertSuccess(
            String whereClause, Object[] anonBinds) {
        SOQLParser.SOQL soql;
        try {
            soql =  TestContexts[TestIndex].getSOQL(
                'FROM ' + MockClaimType + 
                ' WHERE ' + whereClause, null, anonBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            Assert.fail('Unexpected Rule Violation: ' + err.getMessage());
        }
        return soql;
    }

    static SOQLParser.SOQL assertFullQuerySuccess(String fullQuery) {
        SOQLParser.SOQL soql;
        try {
            soql =  TestContexts[TestIndex].getSOQL(
                fullQuery, null, AllNullBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            Assert.fail('Unexpected Rule Violation: ' + err.getMessage());
        }
        return soql;
    }

    static void assertViolation(String whereClause) {
        assertViolation(whereClause, AllNullBinds);
    }

    static void assertViolation(
            String whereClause, Object[] anonBinds) {
        Boolean gotErr = false;
        try {
            TestContexts[TestIndex].getSOQL(
                'FROM ' + MockClaimType + 
                ' WHERE ' + whereClause, null,anonBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            gotErr = true;
        }
        Assert.isTrue(gotErr, 'Missed Rule Violation on: ' + whereClause);
    }

    static void assertFullQueryViolation(String fullQuery) {
        Boolean gotErr = false;
        try {
            TestContexts[TestIndex].getSOQL(
                fullQuery, null, AllNullBinds, null);
        } catch (SOQLContext.RuleViolationException err) {
            gotErr = true;
        }
        Assert.isTrue(gotErr, 'Missed Rule Violation on: ' + fullQuery);
    }

    // Example rule violation exception messages:
    // Rule Violation on [Patient Lookup]: WHERE clause is required
    // Rule Violation on [Patient Lookup][Match Any Of 2][Last Violation]
    //   [Match LastName, Birth, SSN4]: Expected at least 3 qualifying
    //   match terms; got 2
}