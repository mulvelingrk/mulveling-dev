/*
 * Mike Ulveling
 */ 
@IsTest
private class RestrictedSearchesTest {
    static final Schema.SObjectType MockClaimType = Schema.RKUX_Mock_Claim__c.SObjectType;
    static SOQLContext context;

    @IsTest
    private static void TestStrictCustomLookup() {
        context = RestrictedSearches.loadRuleBasedMetadata(
            'LWC - Strict Custom Lookup', MockClaimType, SOQLContext.getDefaultStrictMode());
        
        Assert.areEqual('Restricted Search [RKUX Test SCL]', context.label);
        
        // "LWC - Strict Custom Lookup" For Schema.RKUX_Mock_Claim__c is Configured as Follows:
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
        //String soqlTest = SOQLContext.getDefaultStrictMode().getSafeQuery(
        //        'SELECT Id FROM Contact WHERE Foo > 1', null, AllNullBinds, null);
        //Assert.areEqual('Foo', soqlTest);

        //String soqlTest = context.getSafeQuery(
        //        'SELECT * FROM ' + MockClaimType + ' WHERE Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ?', null, AllNullBinds, null);
        //Assert.areEqual('Foo', soqlTest);

        // Success: meets basic restriction requirements, no more or less:
        String soql = assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ?', 
            new Object[]{ 'Coolio', 'Compton', Date.newInstance(1980, 4, 4) });

        Assert.areEqual(
            'SELECT Id FROM ' + MockClaimType + ' WHERE Mock_Claimant_Last_Name__c = \'Coolio\' AND Claimant_City__c = \'Compton\' AND Date_Claimant_Born__c = 1980-04-03', 
            soql);

        // Success: superfluous groupings should not invalidate the query:
        assertSuccess('(Mock_Claimant_Last_Name__c = ? AND (Claimant_City__c = ? AND Date_Claimant_Born__c = ?))');

        // Success: extra match:
        assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Cause__c = ?');

        // Success: extra freestyle match:
        assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Date_Hired__c = ?');

        // Success: freestyle matches can be in OR and NOT as long as they're under a top-level AND:
        //assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND (Date_Hired__c = ? OR NOT Claimant_Country__c = ?)');

        // Violation: match condition not allowed in OR condition:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND (Claimant_City__c = ? OR Date_Claimant_Born__c = ?)');

        // Violation: top level condition is OR:
        assertViolation('Mock_Claimant_Last_Name__c = ? OR Claimant_City__c = ? OR Date_Claimant_Born__c = ?');

        // Violation: match condition not allowed in NOT condition:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND NOT Date_Claimant_Born__c = ?');

        // Violation: required match condition Mock_Claimant_Last_Name__c is missing:
        assertViolation('Cause__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ?');

        // Violation: does not meet minimum # of matches:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ?');

        // Violation: unsupported ">" operator:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Date_Hired__c > ?');

        // Violation: unsupported "LIKE" operator:
        assertViolation('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Cause LIKE "%"');

        // Violation: unsupported "contains" operator:
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
            soql = context.getSafeQuery(
                'FROM ' + MockClaimType + ' WHERE ' + whereClause, null, anonBinds, null);
        } catch (SOQLContext.RestrictedSearchException err) {
            Assert.fail('Unexpected RestrictedSearch Violation: ' + err.getMessage());
        }
        return soql;
    }

    static void assertViolation(String whereClause) {
        assertViolation(whereClause, AllNullBinds);
    }

    static void assertViolation(String whereClause, Object[] anonBinds) {
        Boolean gotErr = false;
        try {
            context.getSafeQuery(
                'FROM ' + MockClaimType + ' WHERE ' + whereClause, null,anonBinds, null);
        } catch (SOQLContext.RestrictedSearchException err) {
            gotErr = true;
        }
        Assert.isTrue(gotErr, 'Missed RestrictedSearch Violation on: ' + whereClause);
    }
}