@IsTest 
private class SOQLParserTest {
    @IsTest
    private static void testLexerTypes() {
        SOQLContext ctxt = SOQLContext.newSystemMode();
        String actual = ctxt.getQuery('FROM Contact WHERE MailingLatitude Between ([0, 10.5], [20, 30), (50, 60], (80, 90.1256))');
        
        System.assertEquals(
            'SELECT Id FROM Contact WHERE' +
                ' (MailingLatitude >= 0 AND MailingLatitude <= 10.5)' + 
                ' OR (MailingLatitude >= 20 AND MailingLatitude < 30)' + 
                ' OR (MailingLatitude > 50 AND MailingLatitude <= 60)' + 
                ' OR (MailingLatitude > 80 AND MailingLatitude < 90.1256)', 
            actual);

        
        actual = ctxt.getQuery('FROM Contact WHERE LastName = "Foo \\"Bar\\" \'Baz\' \\nQux"');
        System.assertEquals('SELECT Id FROM Contact WHERE' +
            ' LastName = \'Foo "Bar" \\\'Baz\\\' \\nQux\'',  actual);

        actual = ctxt.getQuery('FROM Contact WHERE LastName = \'Foo "Bar" \\\'Baz\\\' \\nQux\'');
        System.assertEquals('SELECT Id FROM Contact WHERE' +
            ' LastName = \'Foo "Bar" \\\'Baz\\\' \\nQux\'',  actual);

        actual = ctxt.getQuery('FROM Contact WHERE MailingLatitude < .5556');

        Boolean caught = false;
        try {
            actual = ctxt.getQuery('FROM Contact WHERE Name = "Unclosed String');
        } catch (SOQLContext.QueryException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Expected string literal syntax error');

        actual = ctxt.getQuery('FROM Contact WHERE Name = "\\u01FC\\x45"');
        Assert.areEqual('SELECT Id FROM Contact WHERE' +
            ' Name = \'ǼE\'',  actual);

        Assert.areEqual(ctxt.getQuery(
            'FROM Contact WHERE LastName = "U" && FirstName = "Mike" || !(MailingState = \'AL\')'),
            'SELECT Id FROM Contact WHERE (LastName = \'U\' AND FirstName = \'Mike\') OR (NOT MailingState = \'AL\')');

        query(ctxt, 'FROM Contact WHERE Birthdate = 1980-04-04');
        query(ctxt, 'FROM Contact WHERE EmailBouncedDate = 1980-04-04T21:15:10-05:00');
        query(ctxt, 'FROM Contact WHERE Birthdate Between [1980-04-04, LAST_YEAR]');
        query(ctxt, 'FROM Contact WHERE Birthdate >= LAST_N_YEARS:20');
        query(ctxt, 'FROM Contact WHERE Birthdate >= NEXT_N_YEARS:-20');
        queryFail(ctxt, 'ParseException', 'FROM Contact WHERE Birthdate >= NEXT_N_YEARS:2.5');
        queryFail(ctxt, 'ParseException', 'FROM Contact WHERE Birthdate >= NEXT_N_YEARS');

        query(ctxt, 'FROM Contact WHERE IsEmailBounced = true');
        query(ctxt, 'FROM Contact WHERE IsEmailBounced = false');
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE Name BeginsWith null');

        query(ctxt, 'FROM Contact WHERE Name IN ("Foo", "Bar", "Baz")');
        ctxt.getSOQL('FROM Contact Where Name = :foo OR Name = :bar OR Name = :baz', new Map<String, Object>{
            'foo' => 'Foo',
            'bar' => 'Bar',
            'baz' => 'Baz'
        }, new Object[]{}, null);

        ctxt.getSOQL('FROM Contact Where Name IN :namesList', new Map<String, Object>{
            'namesList' => new String[]{ 'Foo', 'Bar', 'Baz' }
        }, new Object[]{}, null);

        query(ctxt, 'FROM Contact ORDER BY Account.Name ASC NULLS LAST, Name DESC NULLS LAST LIMIT 1');
        actual = ctxt.getQuery('FROM Contact LIMIT ?', 1);
        Assert.areEqual('SELECT Id FROM Contact LIMIT 1', actual);
        actual = ctxt.getQuery('FROM Contact LIMIT :lmt', new Map<String, Object>{
            'lmt' => 2
        }, null, null);
        Assert.areEqual('SELECT Id FROM Contact LIMIT 2', actual);

        // ======================================================================================================
        // Test param data type conversions over "loose" binding mode (default):
        ctxt.looseBindTypes();

        // String converts to double:
        ctxt.bind('180');
        actual = query(ctxt, 'FROM Contact WHERE MailingLatitude = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE MailingLatitude = 180', actual);

        // Boolean converts to Double:
        ctxt.bind(true);
        actual = query(ctxt, 'FROM Contact WHERE MailingLatitude = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE MailingLatitude = 1', actual);

        // Array does NOT convert to Double:
        ctxt.bind(new Object[]{ 'foo', 'bar' });
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE MailingLatitude = ?');

        // Null converts to Boolean false:
        ctxt.bind(null);
        actual = query(ctxt, 'FROM Contact WHERE IsEmailBounced = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE IsEmailBounced = false', actual);

        // String '1' converts to Boolean true:
        ctxt.bind('1');
        actual = query(ctxt, 'FROM Contact WHERE IsEmailBounced = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE IsEmailBounced = true', actual);

        // String '0' converts to Boolean false:
        ctxt.bind('0');
        actual = query(ctxt, 'FROM Contact WHERE IsEmailBounced = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE IsEmailBounced = false', actual);

        // Double 1.0 converts to Boolean true:
        ctxt.bind(1.0);
        actual = query(ctxt, 'FROM Contact WHERE IsEmailBounced = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE IsEmailBounced = true', actual);

        // Double 0.0 converts to Boolean true:
        ctxt.bind(0.0);
        actual = query(ctxt, 'FROM Contact WHERE IsEmailBounced = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE IsEmailBounced = false', actual);

        // String 'foo' does NOT convert to Boolean:
        ctxt.bind('foo');
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE IsEmailBounced = ?');

        // Array does NOT convert to Boolean:
        ctxt.bind(new Object[]{ 'foo', 'bar' });
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE IsEmailBounced = ?');

        // Lots of data types are convertible to String:
        ctxt.bind(3.14)
            .bind(true)
            .bind(Date.newInstance(2014, 10, 31))
            .bind(Datetime.newInstanceGmt(2014, 10, 31, 13, 30, 15));
        actual = query(ctxt, 'FROM Contact WHERE Name = ? OR Name = ? OR Name = ? OR Name = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE Name = \'3.14\' OR Name = \'true\' OR Name = \'2014-10-31\' OR Name = \'2014-10-31T13:30:15.000Z\'', actual);

         // Array value does NOT convert to String:
         ctxt.bind(new String[]{ 'foo', 'bar' });
         queryFail(ctxt, 'TypeException', 'FROM Contact WHERE Name = ?');

        // Double value 'Infinity' cannot be used in a query because it is not convertible to Decimal:
        ctxt.bind(Double.valueOf('Infinity'));
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE Name = ?');

        // String converts to Date or Datetime types when in the right format:
        ctxt.bind('2014-10-31')
            .bind('2014-10-31T13:30:15.000Z');
            // TODO: this format should work
            //.bind('2014-10-31T13:30:15.000-05:00');
        actual = query(ctxt, 'FROM Contact WHERE Birthdate = ? OR EmailBouncedDate = ?');
        Assert.areEqual('SELECT Id FROM Contact WHERE Birthdate = 2014-10-31 OR EmailBouncedDate = 2014-10-31T13:30:15.000Z', actual);
        
        // ======================================================================================================
        // Test param data type incompatibilities under "strict" binding mode:
        ctxt.strictBindTypes();
        // Boolean to Double:
        ctxt.bind(true);
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE MailingLatitude = ?');

        // Array to Double:
        ctxt.bind(new Object[]{ 'foo', 'bar' });
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE MailingLatitude = ?');

        // Null to Boolean:
        //ctxt.bind(null);
        //queryFail(ctxt, 'TypeException', 'FROM Contact WHERE IsEmailBounced = ?');

        // String to Boolean:
        ctxt.bind('1');
        queryFail(ctxt, 'TypeException','FROM Contact WHERE IsEmailBounced = ?');

        // String to Boolean:
        ctxt.bind('0');
        queryFail(ctxt, 'TypeException','FROM Contact WHERE IsEmailBounced = ?');

        // Double to Boolean:
        ctxt.bind(1.0);
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE IsEmailBounced = ?');

        // Double to Boolean:
        ctxt.bind(0.0);
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE IsEmailBounced = ?');

        // String to Boolean:
        ctxt.bind('foo');
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE IsEmailBounced = ?');

        // Array to Boolean:
        ctxt.bind(new Object[]{ 'foo', 'bar' });
        queryFail(ctxt, 'TypeException', 'FROM Contact WHERE IsEmailBounced = ?');

        // Lots of data types compatible to String in "loose" mode but not "strict":
        String q = 'FROM Contact WHERE Name = ?';
        ctxt.bind(3.14);
        queryFail(ctxt, 'TypeException', q);
        ctxt.bind(true);
        queryFail(ctxt, 'TypeException', q);
        ctxt.bind(Date.newInstance(2014, 10, 31));
        queryFail(ctxt, 'TypeException', q);
        ctxt.bind(Datetime.newInstanceGmt(2014, 10, 31, 13, 30, 15));
        queryFail(ctxt, 'TypeException', q);

        // ======================================================================================================

        ctxt.looseBindTypes();

        ctxt.bind('foo', 'foo_bar%baz');
        actual = query(ctxt, 'FROM Contact WHERE Name Contains :foo');
        Assert.areEqual('SELECT Id FROM Contact WHERE Name LIKE \'%foo\\_bar\\%baz%\'', actual);

        ctxt.bind('foo', 'foo_bar%baz');
        actual = query(ctxt, 'FROM Contact WHERE Name LIKE :foo');
        Assert.areEqual('SELECT Id FROM Contact WHERE Name LIKE \'foo_bar%baz\'', actual);

        ctxt.bindAll(SOQLContext.AllNullBinds);
        String[] rawRefs = ctxt.getSOQL('SELECT Account.Name, LastName FROM Contact WHERE firstname = ? AND ACCOUNT.Name =? AND ReportsTo.Name = ? ORDER BY ReportsTo.Department')
            .getWhereCondition()
            .getRawRefs();
        Assert.areEqual('firstname, ACCOUNT.Name, ReportsTo.Name', String.join(rawRefs, ', '));

        rawRefs = ctxt.getSOQL('SELECT Account.Name, LastName FROM Contact WHERE firstname = ? AND ACCOUNT.Name =? AND ReportsTo.Name = ? ORDER BY ReportsTo.Department')
            .getWhereCondition()
            .getResolvedRefs();
        Assert.areEqual('FirstName, Account.Name, ReportsTo.Name', String.join(rawRefs, ', '));

        ctxt.bindAll(SOQLContext.AllNullBinds);
        SOQLParser.SOQL soql = ctxt.getSOQL('SELECT Account.Name, LastName FROM Contact WHERE FirstName = ?');
        SOQLParser p = soql.parser;
        p.paramBindLoose();
        p.paramBindBlind();
        p.paramBindStrict();
        p.strictRefs(Schema.Contact.SObjectType);
        p.strictRefs(true);
        p.finesseRefs(true);
        p.injectParentRefs(new String[]{ 'foo' });
        p.refProcessor();
        SOQLParser.ReferenceProcessor refProc = new SOQLParser.ReferenceProcessor(p);
        refProc.paramBindLoose();
        refProc.paramBindBlind();
        refProc.paramBindStrict();
        refProc.strictRefs(true);
        refProc.fixNamespaces(true);
        refProc.fixLookupSuffixes(true);
        refProc.injectParentRefs(new String[]{ 'foo' });
        refProc.rewriter(null);
        p.refProcessor(refProc);
    }



    static String query(SOQLContext ctxt, String q) {
        try {
            return ctxt.getQuery(q);
        } catch (SOQLContext.QueryException qe) {
            Assert.fail('Unexpected QueryException: ' + qe.getMessage());
        }
        return null; // unreachable
    }

    static void queryFail(SOQLContext ctxt, String causeType, String q) {
        queryFail(ctxt, causeType, q, null);
    }

    static void queryFail(SOQLContext ctxt, String causeType, String q, String reason) {
        SOQLContext.QueryException error;
        Exception cause;
        try {
            ctxt.getQuery(q);
        } catch (SOQLContext.QueryException qe) {
            error = qe;
            cause = qe.getCause();
        } 
        //catch (SOQLParser.TypeException qe) {
        //    caughtType = 'Type';
        //}
        Assert.isNotNull(error, 'Expected QueryException' + (reason != null ? ' because: ' + reason : ''));
        Assert.areEqual('SOQLParser.' + causeType, cause != null ? cause.getTypeName() : error.getTypeName());
    }
}


//Expected: SELECT Id FRom Contact, Actual: SELECT Id FROM Contact WHERE (MailingLatitude >= 0 AND MailingLatitude <= 10.5) OR (MailingLatitude >= 20 AND MailingLatitude < 30) OR (MailingLatitude > 50 AND MailingLatitude <= 60) OR (MailingLatitude > 80 AND MailingLatitude < 90.1256)