/*
 * Mike Ulveling
 */ 
@IsTest
private class RestrictedSearchesTest {
    static final Schema.SObjectType MockClaimType = Schema.RKUX_Mock_Claim__c.SObjectType;
    static SOQLContext context;

    @IsTest
    private static void TestStrictCustomLookup() {
        context = RestrictedSearches.loadRulesAtopSystemBase(
            'LWC - Strict Custom Lookup', MockClaimType, null);
        
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

        // Success: has the 3 required match terms, AND is the top-level condition, and the superfluous groupings do not confuse the rules engine:
        assertSuccess('(Mock_Claimant_Last_Name__c = ? AND (Claimant_City__c = ? AND Date_Claimant_Born__c = ?))');

        // Success: extra 4th match term (AND) is OK:
        assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Cause__c = ?');

        // Success: extra freestyle term is allowed (AND):
        assertSuccess('Mock_Claimant_Last_Name__c = ? AND Claimant_City__c = ? AND Date_Claimant_Born__c = ? AND Date_Hired__c = ?');

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
            context.getQuery(
                'FROM ' + MockClaimType + ' WHERE ' + whereClause, null,anonBinds, null);
        } catch (SOQLContext.RestrictedSearchException err) {
            gotErr = true;
        }
        Assert.isTrue(gotErr, 'Missed RestrictedSearch Violation on: ' + whereClause);
    }
}