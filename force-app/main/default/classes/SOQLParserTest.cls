@isTest
private class SOQLParserTest {

    @isTest
    static void testEval() {
    	// Resolve test object metadata
    	String dateFieldAPI = qualField('Date__c');
    	String dateTimeFieldAPI = qualField('DateTime__c');
    	String multiSelectFieldAPI = qualField('Picklist_Multiselect__c');
    	String numberFieldAPI = qualField('Number__c');
    	String currencyFieldAPI = qualField('Currency__c');
    	String textFieldAPI = qualField('Text__c');
    	String textAreaFieldAPI = qualField('Text_Area__c');
    	String checkboxFieldAPI = qualField('Checkbox__c');
    	String lookupFieldAPI = qualField('Lookup__c');
    	String lookupFieldAPI_R = lookupFieldAPI.replaceFirst('(?i)__c$', '__r');

    	String[] allFields = new String[]{
    		dateFieldAPI,
    		dateTimeFieldAPI,
    		multiSelectFieldAPI,
    		numberFieldAPI,
    		currencyFieldAPI,
    		textFieldAPI,
    		textAreaFieldAPI,
    		checkboxFieldAPI,
    		lookupFieldAPI
    	};

        DateTime nowTime = System.now();
        Date nowDate = System.today();
        DateTime nextYearTime = nowTime.addYears(1);
        Date nextYearDate = nowDate.addYears(1);
        DateTime lastYearTime = nowTime.addYears(-1);
        Date lastYearDate = nowDate.addYears(-1);

        /*rkl__PortalTestLookupObject__c testParent = new rkl__PortalTestLookupObject__c(
            rkl__DateField__c = lastYearDate,
            rkl__multiselect__c = 'corge;grault;garply;waldo;fred',
            rkl__Number_4_Field__c = -500,
            rkl__TextField__c = 'corge grault garply waldo fred'
        );*/

        SObject testParent = sObjectType.newSObject();
        testParent.put(dateFieldAPI, lastYearDate);
        testParent.put(multiSelectFieldAPI, 'corge;grault;garply;waldo;fred');
        testParent.put(numberFieldAPI, -500);
        testParent.put(textFieldAPI, 'corge grault garply waldo fred');
        insert testParent;

        /*rkl__PortalTestObject__c testChild = new rkl__PortalTestObject__c(
            rkl__Currency_Field__c = 42.5,
            rkl__Text_Area_Field__c = 'foo bar baz qux quux',
            rkl__Multi_Select_Picklist_Field__c = 'foo;bar;baz;qux;quux',
            rkl__Checkbox_Field__c = true,
            rkl__Date_Time_Field__c = nowTime,
            rkl__Date_Field__c = nowDate,
            rkl__Current_Lookup__c = testParent.Id
        );*/
        SObject testChild = sObjectType.newSObject();
        testChild.put(currencyFieldAPI, 42.5);
        testChild.put(textAreaFieldAPI, 'foo bar baz qux quux');
        testChild.put(multiSelectFieldAPI, 'foo;bar;baz;qux;quux');
        testChild.put(checkboxFieldAPI, true);
        testChild.put(dateTimeFieldAPI, nowTime);
        testChild.put(dateFieldAPI, nowDate);
        testChild.put(lookupFieldAPI, testParent.Id);
        insert testChild;

        //SOQLParser p = new SOQLParser(Schema.rkl__PortalTestObject__c.sObjectType);
        SOQLParser p = new SOQLParser(sObjectType);
        
        //SOQLParser.CondExpr cond = p.parseCond('rkl__Currency_Field__c > 42 && rkl__Current_Lookup__r.rkl__TextField__c beginsWith "corge GR" && (rkl__Multi_Select_Picklist_Field__c INCLUDES ("foo", "thud") || rkl__Current_Lookup__r.rkl__multiselect__c EXCLUDES ("thud"))');
        SOQLParser.CondExpr cond = p.parseCond(
        	currencyFieldAPI + ' > 42 && ' +
        	lookupFieldAPI_R + '.' + textFieldAPI + ' beginsWith "corge GR" && ' +
        	'(' +
        		multiSelectFieldAPI + ' INCLUDES ("foo", "thud") || ' +
        		lookupFieldAPI_R + '.' + multiSelectFieldAPI + ' EXCLUDES ("thud")' +
        	')'
    	);

        // TODO: use reference rewriting to replace field references with short variable names...
        //SOQLParser.CondExpr cond = p.parseCond('$curr > 42 && $lkp.txt beginsWith "corge GR" && ($msp INCLUDES ("foo", "thud") || $lkp.msp EXCLUDES ("thud"))');
        // requery our test record to ensure we get the parent relationship sObjects populated:
        /*testChild = (rkl__PortalTestObject__c) Database.query('SELECT ' + 
            SOQLUtils.selectClause(Schema.rkl__PortalTestObject__c.sObjectType, String.join(cond.getResolvedRefs(), ',')) + 
            ' FROM rkl__PortalTestObject__c WHERE Id=\'' + testChild.Id + '\'');*/
        testChild = Database.query(
        	'SELECT ' +
        		RKSecurity.systemSelect(sObjectType, String.join(cond.getResolvedRefs(), ',')) +
        	' FROM ' + sObjectType +
        	' WHERE Id = \'' + testChild.Id + '\''
    	);

        //cond.evalMatchSubResults(testChild, new Boolean[]{ true, true, true, true, true, false, true });
        //Boolean result = cond.eval(testChild);
        //System.debug('\n' + String.join(cond.evalDebug(testChild), '\n'));
        //System.assertEquals(true, result);

        /*testChild = (rkl__PortalTestObject__c) Database.query('SELECT ' + SOQLUtils.selectClause(Schema.rkl__PortalTestObject__c.sObjectType, 'custom') +
            ' FROM rkl__PortalTestObject__c WHERE Id=\'' + testChild.Id + '\'');*/

        testChild = Database.query(
        	'SELECT ' + RKSecurity.systemSelect(sObjectType, String.join(allFields, ',')) +
        	' FROM ' + sObjectType +
        	' WHERE Id =\'' + testChild.Id + '\''
    	);

        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c > YESTERDAY').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' > YESTERDAY').eval(testChild));

        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c = TODAY').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' = TODAY').eval(testChild));
        
        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c = NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' = NEXT_N_DAYS:1').eval(testChild));

        //////
        //testChild.rkl__Date_Time_Field__c = DateTime.newInstance(System.today().addDays(0), Time.newInstance(23,59,59,999));
        //update testChild;
        //System.assertEquals(1, [SELECT count() FROM rkl__PortalTestObject__c WHERE Id=:testChild.Id AND rkl__Date_Time_Field__c = LAST_N_DAYS:2]);
        //////

        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c >= NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' >= NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c <= NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' <= NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Date_Field__c < NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(false, p.parseCond(dateFieldAPI + ' < NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Date_Field__c > NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(false, p.parseCond(dateFieldAPI + ' > NEXT_N_DAYS:1').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c = NEXT_90_DAYS').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' = NEXT_90_DAYS').eval(testChild));

        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c = LAST_N_DAYS:10').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' = LAST_N_DAYS:10').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c >= LAST_N_DAYS:10').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' >= LAST_N_DAYS:10').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c <= LAST_N_DAYS:10').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' <= LAST_N_DAYS:10').eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Date_Field__c > LAST_N_DAYS:1').eval(testChild));
        //System.assertEquals(false, p.parseCond(dateFieldAPI + ' > LAST_N_DAYS:1').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Date_Field__c = LAST_90_DAYS').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateFieldAPI + ' = LAST_90_DAYS').eval(testChild));

        // for DateTime formula ranges, SOQL works as follows:
        // LAST_N_DAYS runs from 00:00:00:000 N days ago (from midnight today) to 23:59:59:999 today (inclusive)
        // NEXT_N_DAYS runs from 00:00:00:000 tomorrow to 23:59:59:999 on N days from midnight today (inclusive)

        //testChild.rkl__Date_Time_Field__c = DateTime.newInstance(System.today().addDays(-1), Time.newInstance(0,0,0,0));
        testChild.put(dateTimeFieldAPI, DateTime.newInstance(System.today().addDays(-1), Time.newInstance(0,0,0,0)));
        update testChild;
        //System.assertEquals(true, p.parseCond('rkl__Date_Time_Field__c = LAST_N_DAYS:2').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateTimeFieldAPI + ' = LAST_N_DAYS:2').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Date_Time_Field__c >= LAST_N_DAYS:2').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateTimeFieldAPI + ' >= LAST_N_DAYS:2').eval(testChild));
        //testChild.rkl__Date_Time_Field__c = DateTime.newInstance(System.today().addDays(1), Time.newInstance(0,0,0,0));
        testChild.put(dateTimeFieldAPI, DateTime.newInstance(System.today().addDays(1), Time.newInstance(0,0,0,0)));
        update testChild;
        //System.assertEquals(true, p.parseCond('rkl__Date_Time_Field__c = NEXT_N_DAYS:2').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateTimeFieldAPI + ' = NEXT_N_DAYS:2').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Date_Time_Field__c <= NEXT_N_DAYS:2').eval(testChild));
        //System.assertEquals(true, p.parseCond(dateTimeFieldAPI + ' <= NEXT_N_DAYS:2').eval(testChild));

        //System.assertEquals(true, p.parseCond('rkl__Checkbox_Field__c <= ?', true).eval(testChild));
        //System.assertEquals(true, p.parseCond(checkboxFieldAPI + ' <= ?', true).eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Checkbox_Field__c = ?', true).eval(testChild));
        //System.assertEquals(true, p.parseCond(checkboxFieldAPI + ' = ?', true).eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Checkbox_Field__c != ?', true).eval(testChild));
        //System.assertEquals(false, p.parseCond(checkboxFieldAPI + ' != ?', true).eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Checkbox_Field__c > ?', true).eval(testChild));
        //System.assertEquals(false, p.parseCond(checkboxFieldAPI + ' > ?', true).eval(testChild));

        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c < ?', 'garply').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' < ?', 'garply').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c != ?', 'garply').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' != ?', 'garply').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c >= ?', 'bar').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' >= ?', 'bar').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c LIKE "foo%"').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' LIKE "foo%"').eval(testChild));

        //System.assertEquals(false, p.parseCond('!(rkl__Text_Area_Field__c LIKE "foo%")').eval(testChild));
        //System.assertEquals(false, p.parseCond('!(' + textAreaFieldAPI + ' LIKE "foo%")').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c LIKE "%bar%"').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' LIKE "%bar%"').eval(testChild));

        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c contains "bar"').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' contains "bar"').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c endsWith "quux"').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' endsWith "quux"').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c LIKE "%qu_x"').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' LIKE "%qu_x"').eval(testChild));

        //System.assertEquals(true, p.parseCond('rkl__Currency_Field__c < ?', Double.valueOf('Infinity')).eval(testChild));
        //System.assertEquals(true, p.parseCond(currencyFieldAPI + ' < ?', Double.valueOf('Infinity')).eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Currency_Field__c < ?', -Double.valueOf('Infinity')).eval(testChild));
        //System.assertEquals(false, p.parseCond(currencyFieldAPI + ' < ?', -Double.valueOf('Infinity')).eval(testChild));
        //System.assertEquals(true, p.parseCond('!(rkl__Currency_Field__c >= ?)', Double.valueOf('Infinity')).eval(testChild));
        //System.assertEquals(true, p.parseCond('!(' + currencyFieldAPI + ' >= ?)', Double.valueOf('Infinity')).eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Currency_Field__c >= ?', Double.valueOf('NaN')).eval(testChild));
        //System.assertEquals(false, p.parseCond(currencyFieldAPI + ' >= ?', Double.valueOf('NaN')).eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Currency_Field__c <= ?', Double.valueOf('NaN')).eval(testChild));
        //System.assertEquals(false, p.parseCond(currencyFieldAPI + ' <= ?', Double.valueOf('NaN')).eval(testChild));

        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c IN ("foo", "foo bar baz qux quux", "bar")').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' IN ("foo", "foo bar baz qux quux", "bar")').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c NOT IN ("foo", "bar", "baz")').eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' NOT IN ("foo", "bar", "baz")').eval(testChild));
        //System.assertEquals(true, p.parseCond('!(rkl__Text_Area_Field__c IN ("foo", "bar"))').eval(testChild));
        //System.assertEquals(true, p.parseCond('!(' + textAreaFieldAPI + ' IN ("foo", "bar"))').eval(testChild));
        //System.assertEquals(true, p.parseCond('!(rkl__Text_Area_Field__c NOT IN ("foo", "foo bar baz qux quux"))').eval(testChild));
        //System.assertEquals(true, p.parseCond('!(' + textAreaFieldAPI + ' NOT IN ("foo", "foo bar baz qux quux"))').eval(testChild));
    }

    @isTest
    static void testParamBind() {
    	// Resolve test object metadata
    	String dateFieldAPI = qualField('Date__c');
    	String dateTimeFieldAPI = qualField('DateTime__c');
    	String multiSelectFieldAPI = qualField('Picklist_Multiselect__c');
    	String numberFieldAPI = qualField('Number__c');
    	String currencyFieldAPI = qualField('Currency__c');
    	String textFieldAPI = qualField('Text__c');
    	String textAreaFieldAPI = qualField('Text_Area__c');
    	String checkboxFieldAPI = qualField('Checkbox__c');
    	String lookupFieldAPI = qualField('Lookup__c');
    	String lookupFieldAPI_R = lookupFieldAPI.replaceFirst('(?i)__c$', '__r');

    	String[] allFields = new String[]{
    		dateFieldAPI,
    		dateTimeFieldAPI,
    		multiSelectFieldAPI,
    		numberFieldAPI,
    		currencyFieldAPI,
    		textFieldAPI,
    		textAreaFieldAPI,
    		checkboxFieldAPI,
    		lookupFieldAPI
    	};

        DateTime nowTime = System.now();
        Date nowDate = System.today();
        DateTime nextYearTime = nowTime.addYears(1);
        Date nextYearDate = nowDate.addYears(1);
        DateTime lastYearTime = nowTime.addYears(-1);
        Date lastYearDate = nowDate.addYears(-1);

        /*rkl__PortalTestLookupObject__c testParent = new rkl__PortalTestLookupObject__c(
            rkl__DateField__c = lastYearDate,
            rkl__multiselect__c = 'corge;grault;garply;waldo;fred',
            rkl__Number_4_Field__c = -500,
            rkl__TextField__c = 'corge grault garply waldo fred'
        );*/

        SObject testParent = sObjectType.newSObject();
        testParent.put(dateFieldAPI, lastYearDate);
        testParent.put(multiSelectFieldAPI, 'corge;grault;garply;waldo;fred');
        testParent.put(numberFieldAPI, -500);
        testParent.put(textFieldAPI, 'corge grault garply waldo fred');
        insert testParent;

        /*rkl__PortalTestObject__c testChild = new rkl__PortalTestObject__c(
            rkl__Currency_Field__c = 42.5,
            rkl__Text_Area_Field__c = 'foo bar baz qux quux',
            rkl__Multi_Select_Picklist_Field__c = 'foo;bar;baz;qux;quux',
            rkl__Checkbox_Field__c = true,
            rkl__Date_Time_Field__c = nowTime,
            rkl__Date_Field__c = nowDate,
            rkl__Current_Lookup__c = testParent.Id
        );*/
        SObject testChild = sObjectType.newSObject();
        testChild.put(currencyFieldAPI, 42.5);
        testChild.put(textAreaFieldAPI, 'foo bar baz qux quux');
        testChild.put(multiSelectFieldAPI, 'foo;bar;baz;qux;quux');
        testChild.put(checkboxFieldAPI, true);
        testChild.put(dateTimeFieldAPI, nowTime);
        testChild.put(dateFieldAPI, nowDate);
        testChild.put(lookupFieldAPI, testParent.Id);
        insert testChild;

        //SOQLParser p = new SOQLParser(Schema.rkl__PortalTestObject__c.sObjectType);
        SOQLParser p = new SOQLParser(sObjectType);
        p.paramBindLoose();
        Map<String, Object> params = new Map<String, Object>{
            'strCurrency' => '42.0',
            'strText' => 'corge GR'
        };
        //SOQLParser.CondExpr cond = p.parseCond('rkl__Currency_Field__c > :strCurrency && rkl__Current_Lookup__r.rkl__TextField__c beginsWith :strText && (rkl__Multi_Select_Picklist_Field__c INCLUDES ("foo", "thud") || rkl__Current_Lookup__r.rkl__multiselect__c EXCLUDES ("thud"))');
        SOQLParser.CondExpr cond = p.parseCond(
        	currencyFieldAPI + ' > :strCurrency && ' +
        	lookupFieldAPI_R + '.' + textFieldAPI + ' beginsWith :strText && ' +
        	'(' +
        		multiSelectFieldAPI + ' INCLUDES ("foo", "thud") || ' +
        		lookupFieldAPI_R + '.' + multiSelectFieldAPI + ' EXCLUDES ("thud")' +
        	')'
    	);
        //cond.bind(params);
        cond.bind(params);
        // TODO: use reference rewriting to replace field references with short variable names...
        //SOQLParser.CondExpr cond = p.parseCond('$curr > 42 && $lkp.txt beginsWith "corge GR" && ($msp INCLUDES ("foo", "thud") || $lkp.msp EXCLUDES ("thud"))');
        // requery our test record to ensure we get the parent relationship sObjects populated:
        /*testChild = (rkl__PortalTestObject__c) Database.query('SELECT ' + 
            SOQLUtils.selectClause(Schema.rkl__PortalTestObject__c.sObjectType, String.join(cond.getResolvedRefs(), ',')) + 
            ' FROM rkl__PortalTestObject__c WHERE Id=\'' + testChild.Id + '\'');*/
        testChild = Database.query(
        	'SELECT ' + RKSecurity.systemSelect(sObjectType, String.join(cond.getResolvedRefs(), ',')) +
        	' FROM ' + sObjectType +
        	' WHERE Id=\'' + testChild.Id + '\''
    	);

        //cond.evalMatchSubResults(testChild, new Boolean[]{ true, true, true, true, true, false, true });
        // test for case-insensitivity on bind params:
        params = new Map<String, Object>{
            'STRcurrency' => '42.0',
            'strtext' => 'corge GR'
        };
        //cond.evalMatchSubResults(testChild, new Boolean[]{ true, true, true, true, true, false, true });

        // bind new param values which change the parent AndExpr result plus its first 2 child SimpleExpr results:
        /*params.put('strCurrency', '43');
        params.put('strText', 'corge gar');
        cond.bind(params);
        cond.evalMatchSubResults(testChild, new Boolean[]{ false, false, false, true, true, false, true });
        params.put('strCurrency', '4.3e+1');
        cond.bind(params);
        cond.evalMatchSubResults(testChild, new Boolean[]{ false, false, false, true, true, false, true });*/

        /*testChild = (rkl__PortalTestObject__c) Database.query('SELECT ' + SOQLUtils.selectClause(Schema.rkl__PortalTestObject__c.sObjectType, 'custom') +
            ' FROM rkl__PortalTestObject__c WHERE Id=\'' + testChild.Id + '\'');*/
        testChild = Database.query(
        	'SELECT ' + RKSecurity.systemSelect(sObjectType, String.join(allFields, ',')) +
        	' FROM ' + sObjectType +
        	' WHERE Id=\'' + testChild.Id + '\''
     	);

        //System.assertEquals(false, p.parseCond('rkl__Checkbox_Field__c < ?', 'true').eval(testChild));
        //System.assertEquals(false, p.parseCond(checkboxFieldAPI + ' < ?', 'true').eval(testChild));
        //System.assertEquals(false, p.parseCond('rkl__Checkbox_Field__c < ?', '1').eval(testChild));
        //System.assertEquals(false, p.parseCond(checkboxFieldAPI + ' < ?', '1').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Checkbox_Field__c > ?', 'false').eval(testChild));
        //System.assertEquals(true, p.parseCond(checkboxFieldAPI + ' > ?', 'false').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Checkbox_Field__c > ?', '0').eval(testChild));
        //System.assertEquals(true, p.parseCond(checkboxFieldAPI + ' > ?', '0').eval(testChild));

        params = new Map<String, Object>{
            'text' => 'foo%'
        };
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c LIKE :text').bind(params).eval(testChild));
        //System.assertEquals(true, p.parseCond(textAreaFieldAPI + ' LIKE :text').bind(params).eval(testChild));
        //System.assertEquals(false, p.parseCond('!(rkl__Text_Area_Field__c LIKE "foo%")').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c LIKE "%bar%"').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c contains "bar"').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c endsWith "quux"').eval(testChild));
        //System.assertEquals(true, p.parseCond('rkl__Text_Area_Field__c LIKE "%qu_x"').eval(testChild));

        SOQLParser.TypeException typeErr;
        try {
            //cond = p.parseCond('rkl__Checkbox_Field__c = ?', 'das not it mane');
            cond = p.parseCond(checkboxFieldAPI + ' = ?', 'das not it mane');
        } catch (SOQLParser.TypeException err) {
            typeErr = err;
        }
        System.assert(typeErr != null, 'Expected type error for invalid boolean conversion');
        
        // now switch to strict param bind mode, and verify that any type disparity causes a TypeError:
        p.paramBindStrict();
        try {
            //cond = p.parseCond('rkl__Checkbox_Field__c = ?', 'true');
            cond = p.parseCond(checkboxFieldAPI + ' = ?', 'true');
        } catch (SOQLParser.TypeException err) {
            typeErr = err;
        }
        System.assert(typeErr != null, 'Expected type error');
        typeErr = null;
        try {
            //cond = p.parseCond('rkl__Text_Area_Field__c = ?', 42);
            cond = p.parseCond(textAreaFieldAPI + ' = ?', 42);
        } catch (SOQLParser.TypeException err) {
            typeErr = err;
        }
        System.assert(typeErr != null, 'Expected type error');
        typeErr = null;
        try {
            //cond = p.parseCond('rkl__Currency_Field__c = ?', '42');
            cond = p.parseCond(currencyFieldAPI + ' = ?', '42');
        } catch (SOQLParser.TypeException err) {
            typeErr = err;
        }
        System.assert(typeErr != null, 'Expected type error');
        typeErr = null;
        try {
            //cond = p.parseCond('rkl__Date_Field__c = ?', '2016-07-21');
            cond = p.parseCond(dateFieldAPI + ' = ?', '2016-07-21');
        } catch (SOQLParser.TypeException err) {
            typeErr = err;
        }
        System.assert(typeErr != null, 'Expected type error');
        typeErr = null;
        try {
            //cond = p.parseCond('rkl__Date_Time_Field__c = ?', '2016-07-21T12:00:00.000Z');
            cond = p.parseCond(dateTimeFieldAPI + ' = ?', '2016-07-21T12:00:00.000Z');
        } catch (SOQLParser.TypeException err) {
            typeErr = err;
        }
        System.assert(typeErr != null, 'Expected type error');
    }
    
    @isTest
    static void test1() {
    	// Resolve test object metadata
    	String dateFieldAPI = qualField('Date__c');
    	String dateTimeFieldAPI = qualField('DateTime__c');
    	String multiSelectFieldAPI = qualField('Picklist_Multiselect__c');
    	String numberFieldAPI = qualField('Number__c');
    	String currencyFieldAPI = qualField('Currency__c');
    	String textFieldAPI = qualField('Text__c');
    	String textAreaFieldAPI = qualField('Text_Area__c');
    	String checkboxFieldAPI = qualField('Checkbox__c');
    	String lookupFieldAPI = qualField('Lookup__c');
    	String lookupFieldAPI_R = lookupFieldAPI.replaceFirst('(?i)__c$', '__r');

    	String[] allFields = new String[]{
    		dateFieldAPI,
    		dateTimeFieldAPI,
    		multiSelectFieldAPI,
    		numberFieldAPI,
    		currencyFieldAPI,
    		textFieldAPI,
    		textAreaFieldAPI,
    		checkboxFieldAPI,
    		lookupFieldAPI
    	};

        String soql1 = 'baz__c = 2014-12-31 OR foo__r.bar__c >= 42.5 AND NOT foo__c IN ("foo", "bar", "baz", )';
        SOQLLexer lex = SOQLLexer.newLexer(soql1);
        System.assertEquals('NAME[baz__c] = NUMBER[2014] - NUMBER[12] - NUMBER[31] OR NAME[foo__r] . NAME[bar__c] >= NUMBER[42.5] AND NOT NAME[foo__c] IN ( STRING["foo"] , STRING["bar"] , STRING["baz"] , ) <EOF>', lex.toString());

        SOQLParser.CondExpr cond = new SOQLParser().parseCond(soql1);
        System.assertEquals('baz__c = 2014-12-31 OR (foo__r.bar__c >= 42.5 AND (NOT foo__c IN (\'foo\',\'bar\',\'baz\')))', cond.ser());
        System.assertEquals('baz__c,foo__r.bar__c,foo__c', String.join(cond.getRawRefs(), ','));
        System.assertEquals('baz__c,foo__r.bar__c,foo__c', String.join(cond.getResolvedRefs(), ','));
        cond.resolveRefs(new SOQLParser.ReferenceProcessor().injectParentRefs(new String[]{ 'qux__r' }));
        System.assertEquals('baz__c,foo__r.bar__c,foo__c', String.join(cond.getRawRefs(), ','));
        System.assertEquals('qux__r.baz__c,qux__r.foo__r.bar__c,qux__r.foo__c', String.join(cond.getResolvedRefs(), ','));

        cond = new SOQLParser().parseCond('foo__c=1');
        cond = cond.andx('bar__c=?', Date.newInstance(2014, 4, 4));
        System.assertEquals('foo__c = 1 AND bar__c = 2014-04-04', cond.ser());

        cond = SOQLParser.p('foo__c=? AND bar__c beginsWith ?', 42, 'corge%grault_"garply"');
        System.assertEquals('foo__c = 42 AND bar__c LIKE \'corge\\%grault\\_"garply"%\'', cond.ser());

        //////
        Boolean caughtErr = false;
        try {
            // this should throw an error because an unresolved binding parameter cannot be used with the 
            // beginsWith/endsWith/contains ops:
            cond = SOQLParser.p('bar__c beginsWith :foo');
            cond.ser();
        } catch (SOQLParser.SerializerException e) {
            caughtErr = true;
        }
        System.assert(caughtErr);
        System.assertEquals(0, SOQLParser.errorLoc.line);
        System.assertEquals(18, SOQLParser.errorLoc.col);

        // backslashes on '%' and '_' are retained but not doubled-up:
        cond = SOQLParser.p('bar__c beginsWith "foo\\%bar\\_baz\\\'qux\\m"');
        System.assertEquals('bar__c LIKE \'foo\\%bar\\_baz\\\'quxm%\'', cond.ser());

        // unbackslashed '%' and '_' are backslashed:
        cond = SOQLParser.p('bar__c beginsWith "foo%bar_baz\'qux\\m"');
        System.assertEquals('bar__c LIKE \'foo\\%bar\\_baz\\\'quxm%\'', cond.ser());

        cond = SOQLParser.p('bar__c beginsWith \'foo\\%bar\\_baz\\\'qux\\m\'');
        System.assertEquals('bar__c LIKE \'foo\\%bar\\_baz\\\'quxm%\'', cond.ser());

        cond = SOQLParser.p('bar__c beginsWith \'foo\\%bar\\_baz\\"qux\\m\'');
        System.assertEquals('bar__c LIKE \'foo\\%bar\\_baz"quxm%\'', cond.ser());

        cond = SOQLParser.p('bar__c beginsWith \'foo\\%bar\\_baz"qux\\m\'');
        System.assertEquals('bar__c LIKE \'foo\\%bar\\_baz"quxm%\'', cond.ser());

        cond = SOQLParser.p('bar__c endsWith "\\u0046\\u004F\\x4F"');
        System.assertEquals('bar__c LIKE \'%FOO\'', cond.ser());

        // 2-char lookahead decimal number:
        cond = SOQLParser.p('bar__c >= .9345');
        System.assertEquals('bar__c >= 0.9345', cond.ser());

        // \n line-continuation:
        cond = SOQLParser.p('bar__c != "foo-\\\nbar"');
        System.assertEquals('bar__c != \'foo-bar\'', cond.ser());

        // \r\n line-continuation:
        cond = SOQLParser.p('bar__c != \'foo-\\\r\nbar\'');
        System.assertEquals('bar__c != \'foo-bar\'', cond.ser());

        // SyntaxException unterminated string:
        caughtErr = false;
        try {
            // this should throw an error because an unresolved binding parameter cannot be used with the 
            // beginsWith/endsWith/contains ops:
            SOQLParser.p('bar__c beginsWith "foo').ser();
        } catch (SOQLParser.ParseException e) {
            caughtErr = true;
        }
        System.assert(caughtErr);
        System.assertEquals(0, SOQLParser.errorLoc.line);
        System.assertEquals(18, SOQLParser.errorLoc.col);

        // SyntaxException illegal token (not-equals expected):
        caughtErr = false;
        try {
            // this should throw an error because an unresolved binding parameter cannot be used with the 
            // beginsWith/endsWith/contains ops:
            SOQLParser.p('bar__c !+ "foo"').ser();
        } catch (SOQLParser.ParseException e) {
            caughtErr = true;
        }
        System.assert(caughtErr);
        System.assertEquals(0, SOQLParser.errorLoc.line);
        System.assertEquals(7, SOQLParser.errorLoc.col);

        // test auto-ordering on between strings:
        cond = SOQLParser.p('bar__c between (["foo\\_\\\\", "bar\\%\\\\"])');
        System.assertEquals('bar__c >= \'bar%\\\\\' AND bar__c <= \'foo_\\\\\'', cond.ser());

        cond = SOQLParser.p('bar__c between ([?, ?])', 'foo', 'bar');
        System.assertEquals('bar__c >= \'bar\' AND bar__c <= \'foo\'', cond.ser());

        ///////

        cond = SOQLParser.p('foo__c = ?', 42)
            .andNot('bar__c BEGINSWITH ?', 'corge%grault_"garply"');
        System.assertEquals('foo__c = 42 AND (NOT bar__c LIKE \'corge\\%grault\\_"garply"%\')', cond.ser());

        cond = SOQLParser.p('foo__c between ((1,2],[3,4],(6,5],(8,7))');
        //System.assertEquals('foo__c BETWEEN (1,2,3,4,5,6,7,8)', cond.ser());
        System.assertEquals('(foo__c > 1 AND foo__c <= 2) OR (foo__c >= 3 AND foo__c <= 4) OR (foo__c >= 5 AND foo__c < 6) OR (foo__c > 7 AND foo__c < 8)', cond.ser());

        cond = SOQLParser.p('NOT foo__c between ((1,2],[3,4],(6,5],(8,7))');
        System.assertEquals('NOT ((foo__c > 1 AND foo__c <= 2) OR (foo__c >= 3 AND foo__c <= 4) OR (foo__c >= 5 AND foo__c < 6) OR (foo__c > 7 AND foo__c < 8))', cond.ser());

        cond = SOQLParser.p('NOT foo__c between ((?,?],[?,?],(?,?],(?,?))', new Object[]{1,2,3,4,6,5,8,7});
        System.assertEquals('NOT ((foo__c > 1 AND foo__c <= 2) OR (foo__c >= 3 AND foo__c <= 4) OR (foo__c >= 5 AND foo__c < 6) OR (foo__c > 7 AND foo__c < 8))', cond.ser());

        cond = SOQLParser.p('foo__c between [2,1)');
        System.assertEquals('foo__c > 1 AND foo__c <= 2', cond.ser());

        cond = SOQLParser.p('foo__c between ([?,?),(?,?,])', 4, 2, 6, 8);
        System.assertEquals('(foo__c > 2 AND foo__c <= 4) OR (foo__c > 6 AND foo__c <= 8)', cond.ser());

        cond = SOQLParser.p('foo__c between (:foo,:bar)', new Map<String, Object>{
                'FOO' => 'abc',
                'BAR' => 'def'
            });
        System.assertEquals('foo__c > \'abc\' AND foo__c < \'def\'', cond.ser());

        // test a date literal:
        System.assertEquals('foo__c > 2010-04-03', SOQLParser.p('foo__c > 2010-4-3').ser());
        Date dateVal = Date.newInstance(2010, 4, 3);
        System.assertEquals('foo__c > 2010-04-03', SOQLParser.p('foo__c > ?', dateVal).ser());

        // test a datetime literal with a timezone offset and fractional seconds:
        System.assertEquals('foo__c > 2010-04-03T17:25:30.500Z', SOQLParser.p('foo__c > 2010-04-03T12:15:30.50-5:10').ser());
        // and now with the UTC 'Z' timezone (0 offset):
        System.assertEquals('foo__c > 2010-04-03T12:15:30.510Z', SOQLParser.p('foo__c > 2010-04-03T12:15:30.51Z').ser());
        DateTime dateTimeVal = DateTime.newInstanceGMT(Date.newInstance(2010, 04, 03), Time.newInstance(17, 15, 30, 500));
        System.assertEquals('foo__c > 2010-04-03T17:15:30.500Z', SOQLParser.p('foo__c > ?', dateTimeVal).ser());

        Boolean gotErr = false;
        try {
            // this is a parse error because it's not a complete Simple Expression (no operator or right-hand side):
            cond = SOQLParser.p('foo__c.bar__c');
        } catch (SOQLParser.ParseException parseErr) {
            gotErr = true;
        }
        System.assert(gotErr, 'Expected parse error for incomplete simple expression');

        // verify that binding of all anonymous params at time of parse is enforced:
        gotErr = false;
        try {
            SOQLParser.p('foo__c = ?');
        } catch (SOQLParser.ParseException parseErr) {
            System.assert(parseErr.getMessage().containsIgnoreCase('anonymous'),
                'Expected SyntaxError for unbound anonymous parameter; got ' + parseErr.getMessage());
            gotErr = true;
        }
        System.assert(gotErr, 'Expected SyntaxError for unbound anonymous parameter');

        gotErr = false;
        try {
            //SOQLParser p = new SOQLParser(Schema.rkl__RK_Hierarchy_Node__c.sObjectType);
            SOQLParser p = new SOQLParser(sObjectType);
            //p.parseCond('rkl__Node_Level__c = 2014-04-04').ser();
            p.parseCond(numberFieldAPI + ' = 2014-04-04').ser();
        } catch (SOQLParser.ErrorException err) {
            System.assert(SOQLParser.getErrorType(err) == 'TypeError',
                'Expected TypeError for type mismatch; got ' + SOQLParser.getErrorType(err) + ': ' + err.getMessage());
            gotErr = true;
        }
        System.assert(gotErr, 'Expected TypeError for type mismatch; got no error');


        // TODO: test handling of string escapes...
    }

    @isTest
    static void testParamBindingTypeConversions() {
    	// Resolve test object metadata
    	String dateFieldAPI = qualField('Date__c');
    	String dateTimeFieldAPI = qualField('DateTime__c');
    	String multiSelectFieldAPI = qualField('Picklist_Multiselect__c');
    	String numberFieldAPI = qualField('Number__c');
    	String currencyFieldAPI = qualField('Currency__c');
    	String textFieldAPI = qualField('Text__c');
    	String textAreaFieldAPI = qualField('Text_Area__c');
    	String checkboxFieldAPI = qualField('Checkbox__c');
    	String lookupFieldAPI = qualField('Lookup__c');
    	String lookupFieldAPI_R = lookupFieldAPI.replaceFirst('(?i)__c$', '__r');

    	String[] allFields = new String[]{
    		dateFieldAPI,
    		dateTimeFieldAPI,
    		multiSelectFieldAPI,
    		numberFieldAPI,
    		currencyFieldAPI,
    		textFieldAPI,
    		textAreaFieldAPI,
    		checkboxFieldAPI,
    		lookupFieldAPI
    	};

        //SOQLParser.P.anchorType(Schema.rkl__PortalTestObject__c.sObjectType);
        //SOQLParser.P.anchorType(sObjectType);

        SOQLParser p = new SOQLParser(sObjectType);

        //System.assertEquals('rkl__Date_Field__c = 2016-04-04', SOQLParser.p('rkl__Date_Field__c = ?', '2016-04-4').ser());
        System.assertEquals(dateFieldAPI + ' = 2016-04-04', p.parseCond(dateFieldAPI + ' = ?', '2016-04-4').ser());
        Boolean caughtTypeErr = false;
        try {
            //SOQLParser.p('rkl__Date_Field__c = ?', 'InvalidDate').ser();
            //SOQLParser.p(dateFieldAPI + ' = ?', 'InvalidDate').ser();
            p.parseCond(dateFieldAPI + ' = ?', 'InvalidDate').ser();
        } catch (SOQLParser.TypeException e) {
            caughtTypeErr = true;
        }
        System.assert(caughtTypeErr, 'Expected TypeError for invalid Date format');
    }

    @isTest
    static void testListAnonParam() {
        //SOQLParser.P.anchorType(Schema.AsyncApexJob.sObjectType);
        final String[] completionStatuses = new String[]{ 'Completed', 'Aborted', 'Failed' };
        System.assertEquals('Status IN (\'' + String.join(completionStatuses, '\',\'') + '\')', 
            SOQLParser.p('Status IN ?', completionStatuses).ser());
        System.assertEquals('Status NOT IN (\'' + String.join(completionStatuses, '\',\'') + '\')', 
            SOQLParser.p('Status NOT IN ?', completionStatuses).ser());
    }

    @isTest
    static void test2() {
    	// Resolve test object metadata
    	String dateFieldAPI = qualField('Date__c');
    	String dateTimeFieldAPI = qualField('DateTime__c');
    	String multiSelectFieldAPI = qualField('Picklist_Multiselect__c');
    	String numberFieldAPI = qualField('Number__c');
    	String currencyFieldAPI = qualField('Currency__c');
    	String textFieldAPI = qualField('Text__c');
    	String textAreaFieldAPI = qualField('Text_Area__c');
    	String checkboxFieldAPI = qualField('Checkbox__c');
    	String lookupFieldAPI = qualField('Lookup__c');
    	String lookupFieldAPI_R = lookupFieldAPI.replaceFirst('(?i)__c$', '__r');

    	String[] allFields = new String[]{
    		dateFieldAPI,
    		dateTimeFieldAPI,
    		multiSelectFieldAPI,
    		numberFieldAPI,
    		currencyFieldAPI,
    		textFieldAPI,
    		textAreaFieldAPI,
    		checkboxFieldAPI,
    		lookupFieldAPI
    	};

        String ser = SOQLParser.p('foo=1')
            .andx('fooBar=42')
            .andx('baz=? OR qux=?', 3, 4)
            .andx('qux=? OR quux=? OR corge=?', 5, 6, 7)
            .andx('grault=? OR garply=? OR waldo=? OR fred=?', 5, 6, 7, 8)
            .andx('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=?', 5, 6, 7, 8, 9)
            .andx('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=? OR thud=?', 5, 6, 7, 8, 9, 10)
            .ser();

        ser = SOQLParser.p('foo=1')
            .andNot('fooBar=42')
            .andNot('baz=? OR qux=?', 3, 4)
            .andNot('qux=? OR quux=? OR corge=?', 5, 6, 7)
            .andNot('grault=? OR garply=? OR waldo=? OR fred=?', 5, 6, 7, 8)
            .andNot('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=?', 5, 6, 7, 8, 9)
            .andNot('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=? OR thud=?', 5, 6, 7, 8, 9, 10)
            .ser();

        ser = SOQLParser.p('foo=1')
            .orNot('fooBar=42')
            .orNot('fooBar=?', 1)
            .orNot('baz=? OR qux=?', 3, 4)
            .orNot('qux=? OR quux=? OR corge=?', 5, 6, 7)
            .orNot('grault=? OR garply=? OR waldo=? OR fred=?', 5, 6, 7, 8)
            .orNot('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=?', 5, 6, 7, 8, 9)
            .orNot('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=? OR thud=?', 5, 6, 7, 8, 9, 10)
            .ser();

        SOQLParser.CondExpr cond = SOQLParser.p('foo=1')
            .orx('fooBar=42')
            .orx('fooBar=?', 1)
            .orx('baz=? OR qux=?', 3, 4)
            .orx('qux=? OR quux=? OR corge=?', 5, 6, 7)
            .orx('grault=? OR garply=? OR waldo=? OR fred=?', 5, 6, 7, 8)
            .orx('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=?', 5, 6, 7, 8, 9)
            .orx('grault=? OR garply=? OR waldo=? OR fred=? OR xyzzy=? OR thud=?', 5, 6, 7, 8, 9, 10);
        cond.empty();
        System.assert(cond.isEmpty());
        cond.ser();

        SOQLParser.p('foo >= NEXT_N_YEARS:2');
        SOQLParser.p('foo >= NEXT_N_QUARTERS:-2');
        SOQLParser.p('foo IN (:0, :1, :2)');
        SOQLParser.p('foo=1 AND (bar=2 OR baz=3)');
    
        SOQLParser.restoreDefaults();
        /*SOQLParser p = new SOQLParser()
            .anchorType(Schema.rkl__RK_Hierarchy_Node__c.sObjectType)
            .strictRefs(Schema.rkl__RK_Hierarchy_Node__c.sObjectType)
            .strictRefs(true)
            .strictTypes(Schema.rkl__RK_Hierarchy_Node__c.sObjectType)
            .strictTypes(true)
            .injectParentRefs(new String[]{'rkl__Parent_Node__r'})
            .finesseRefs(true);*/

        SOQLParser p = new SOQLParser(sObjectType)
            .strictRefs(sObjectType)
            .strictRefs(true)
            .strictTypes(sObjectType)
            .strictTypes(true)
            .injectParentRefs(new String[]{lookupFieldAPI_R})
            .finesseRefs(true);

        SOQLParser.p('foo=?', 1, 2, 3);
        SOQLParser.p('foo=?', 1, 2, 3, 4, 5);
        SOQLParser.p('foo=?', 1, 2, 3, 4, 5, 6);
        new SOQLParser().parseCond('foo=:foo', new Map<String, Object>{ 'foo' => 42 }).ser();

        p = new SOQLParser();
        p.parseCond('foo=?', 1, 2, 3);
        p.parseCond('foo=?', 1, 2, 3, 4);
        p.parseCond('foo=?', 1, 2, 3, 4, 5);
        p.parseCond('foo=?', 1, 2, 3, 4, 5, 6);

        SOQLParser.p('foo=true OR bar=null OR baz=2014-01-01 OR qux=2014-01-01T00:00:00Z OR quux="foo\\%bar\\_baz"').ser();
    }

    @isTest
    static void addlTests() {
    	// Resolve test object metadata
    	String dateFieldAPI = qualField('Date__c');
    	String dateTimeFieldAPI = qualField('DateTime__c');
    	String multiSelectFieldAPI = qualField('Picklist_Multiselect__c');
    	String numberFieldAPI = qualField('Number__c');
    	String currencyFieldAPI = qualField('Currency__c');
    	String textFieldAPI = qualField('Text__c');
    	String textAreaFieldAPI = qualField('Text_Area__c');
    	String checkboxFieldAPI = qualField('Checkbox__c');
    	String lookupFieldAPI = qualField('Lookup__c');
    	String lookupFieldAPI_R = lookupFieldAPI.replaceFirst('(?i)__c$', '__r');

    	String[] allFields = new String[]{
    		dateFieldAPI,
    		dateTimeFieldAPI,
    		multiSelectFieldAPI,
    		numberFieldAPI,
    		currencyFieldAPI,
    		textFieldAPI,
    		textAreaFieldAPI,
    		checkboxFieldAPI,
    		lookupFieldAPI
    	};

        SOQLParser p = new SOQLParser();
        p.refProcessor(p.refProcessor());
        SOQLParser.CondExpr expr = new SOQLParser.CondExpr();
        expr.getParser();
        SOQLParser.CondExpr topExpr = p.parseCond('Foo__c = 42').andx(expr);
        expr.getParser();
        topExpr.empty();
        System.assert(topExpr.isEmpty());
        expr.empty();

        //p = new SOQLParser(Schema.rkl__PortalTestObject__c.sObjectType);
        p = new SOQLParser(sObjectType);
        p.paramBindBlind();
        //expr = p.parseCond('rkl__Date_Field__c > :foo', new Map<String, Object>{ 'foo' => true });
        expr = p.parseCond(dateFieldAPI + ' > :foo', new Map<String, Object>{ 'foo' => true });
        expr.andx(p.parseCond(''));
        //expr.andx(p.parseCond('rkl__Date_Field__c <= :bar', new Map<String, Object>{ 'bar' => 42 }));
        expr.andx(p.parseCond(dateFieldAPI + ' <= :bar', new Map<String, Object>{ 'bar' => 42 }));
        //p.parseCond('').andx(p.parseCond('rkl__Date_Field__c <= TODAY'));
        p.parseCond('').andx(p.parseCond(dateFieldAPI + ' <= TODAY'));
        expr.orx(p.parseCond(''));
        //expr.orx(p.parseCond('rkl__Date_Field__c <= :bar', new Map<String, Object>{ 'bar' => 42 }));
        expr.orx(p.parseCond(dateFieldAPI + ' <= :bar', new Map<String, Object>{ 'bar' => 42 }));
        //p.parseCond('').orx(p.parseCond('rkl__Date_Field__c <= TODAY'));
        p.parseCond('').orx(p.parseCond(dateFieldAPI + ' <= TODAY'));

        /*System.assertEquals('rkl__Text_Area_Field__c > \'abc\\\'d\'', 
            p.parseCond('rkl__Text_Area_Field__c > :foo').bindValues(
                new SOQLParser.ValueResolver(new Map<String, Object>{ 'foo' => 'abc\'d' })).ser());*/
        System.assertEquals(textAreaFieldAPI + ' > \'abc\\\'d\'', 
            p.parseCond(textAreaFieldAPI + ' > :foo').bindValues(
                new SOQLParser.ValueResolver(new Map<String, Object>{ 'foo' => 'abc\'d' })).ser());

        /*System.assertEquals('rkl__Text_Area_Field__c > \'abc\'', 
            p.parseCond('rkl__Text_Area_Field__c > "abc"').ser(new SOQLParser.ReferenceProcessor(Schema.rkl__PortalTestObject__c.sObjectType)));*/
        System.assertEquals(textAreaFieldAPI + ' > \'abc\'', 
            p.parseCond(textAreaFieldAPI + ' > "abc"').ser(new SOQLParser.ReferenceProcessor(sObjectType)));
        //p.parseCond('rkl__Text_Area_Field__c > "abc"').resolveRefs();
        p.parseCond(textAreaFieldAPI + ' > "abc"').resolveRefs();
        //expr = p.parseCond('rkl__Date_Field__c > YESTERDAY');
        expr = p.parseCond(dateFieldAPI + ' > YESTERDAY');
        //rkl__PortalTestObject__c testObjToday = new rkl__PortalTestObject__c(rkl__Date_Field__c = System.today());
        SObject testObjToday  = sObjectType.newSObject();
        testObjToday.put(dateFieldAPI, System.today());
        //expr.evalDebug(testObjToday);
        //System.assertEquals(' WHERE rkl__Date_Field__c > YESTERDAY', expr.whereClause());
        System.assertEquals(' WHERE ' + dateFieldAPI + ' > YESTERDAY', expr.whereClause());
        System.assert(expr instanceof SOQLParser.SimpleExpr);
        SOQLParser.SimpleExpr simpleExpr = (SOQLParser.SimpleExpr) expr;
        System.assertEquals(SOQLLexer.GREATER_THAN, simpleExpr.originalRelOp.ttype);
        System.assertEquals('>', simpleExpr.originalRelOpLexeme);
        System.assert(!simpleExpr.isNotInOp);
        //simpleExpr.traverse(new SOQLEvaluator(new SOQLParser.ReferenceProcessor(Schema.rkl__PortalTestObject__c.sObjectType), testObjToday));
        //simpleExpr.traverse(new SOQLEvaluator(new SOQLParser.ReferenceProcessor(sObjectType), testObjToday));
        //simpleExpr.empty();
        //System.assert(!simpleExpr.isSetOp);

        //expr = p.parseCond('NOT rkl__Date_Field__c > YESTERDAY');
        expr = p.parseCond('NOT ' + dateFieldAPI + ' > YESTERDAY');
        System.assert(expr instanceof SOQLParser.NotExpr);
        SOQLParser.NotExpr notExpr = (SOQLParser.NotExpr) expr;
        notExpr.empty();
        //System.assertEquals('rkl__Date_Field__c > true', 
        //    expr.andx(p.parseCond('')).ser());
        //System.assertEquals('rkl__Date_Field__c > true AND rkl__Date_Field__c <= 42', 
        //    expr.andx(p.parseCond('rkl__Date_Field__c <= :bar', new Map<String, Object>{ 'bar' => 42 })).ser());
        //System.assertEquals('rkl__Date_Field__c <= TODAY', 
        //    p.parseCond('').andx(p.parseCond('rkl__Date_Field__c <= TODAY')).ser());

        p = new SOQLParser(sObjectType);
        //expr = p.parseCond('rkl__Date_Field__c > YESTERDAY');
        expr = p.parseCond(dateFieldAPI + ' > YESTERDAY');
        //expr.processRefs(Schema.rkl__PortalTestObject__c.sObjectType, true);
        expr.processRefs(sObjectType, true);
        //expr.processRefs(new SOQLParser.ReferenceProcessor(Schema.rkl__PortalTestObject__c.sObjectType).clobberPrior(false));
        expr.processRefs(new SOQLParser.ReferenceProcessor(sObjectType).clobberPrior(false));

        //p = new SOQLParser(Schema.rkl__PortalTestObject__c.sObjectType).paramBindLoose();
        p = new SOQLParser(sObjectType).paramBindLoose();
        Map<String, Object> binds = new Map<String, Object>{
            'dt0' => null,
            'dt1' => '2016-02-22T20:34:35.179Z',
            'dt2' => 'Tue Feb 23 2016 10:30:34 GMT-0500',
            'dt3' => 0,
            'dt4' => Date.newInstance(2017, 5, 25)
        };
        // hit DateTime conversions from null, JSON DateTime, JavaScript DateTime String, UTC timestamp, Date:
        //expr = p.parseCond('rkl__Date_Time_Field__c != :dt0 && rkl__Date_Time_Field__c > :dt1 && rkl__Date_Time_Field__c > :dt2 && rkl__Date_Time_Field__c != :dt3 && rkl__Date_Time_Field__c != :dt4', binds);
        expr = p.parseCond(
        	dateTimeFieldAPI + ' != :dt0 && ' +
        	dateTimeFieldAPI + ' > :dt1 && ' +
        	dateTimeFieldAPI + ' > :dt2 && ' +
        	dateTimeFieldAPI + ' != :dt3 && ' +
        	dateTimeFieldAPI + ' != :dt4',
    		binds
    	);
        //System.assertEquals('rkl__Date_Time_Field__c != null AND rkl__Date_Time_Field__c > 2016-02-22T20:34:35.179Z AND rkl__Date_Time_Field__c > 2016-02-23T15:30:34.000Z AND rkl__Date_Time_Field__c != 1970-01-01T00:00:00.000Z AND rkl__Date_Time_Field__c != 2017-05-25T00:00:00.000Z', expr.ser());
        System.assertEquals(
        	dateTimeFieldAPI + ' != null AND ' +
        	dateTimeFieldAPI + ' > 2016-02-22T20:34:35.179Z AND ' +
        	dateTimeFieldAPI + ' > 2016-02-23T15:30:34.000Z AND ' + 
        	dateTimeFieldAPI + ' != 1970-01-01T00:00:00.000Z AND ' + 
        	dateTimeFieldAPI + ' != 2017-05-25T00:00:00.000Z',
        	expr.ser()
    	);
        binds = new Map<String, Object>{
            'dt0' => null,
            'dt1' => '2016-02-22',
            'dt2' => 'Tue Feb 23 2016',
            'dt3' => 0,
            'dt4' => DateTime.newInstance(Date.newInstance(2017, 5, 25), Time.newInstance(5, 12, 55, 0))
        };
        // hit Date conversions from null, JSON DateTime, JavaScript DateTime String, UTC timestamp, DateTime:
        //expr = p.parseCond('rkl__Date_Field__c != :dt0 && rkl__Date_Field__c > :dt1 && rkl__Date_Field__c > :dt2 && rkl__Date_Field__c != :dt3 && rkl__Date_Field__c != :dt4', binds);
        expr = p.parseCond(
        	dateFieldAPI + ' != :dt0 && ' +
        	dateFieldAPI + ' > :dt1 && ' +
        	dateFieldAPI + ' > :dt2 && ' +
        	dateFieldAPI + ' != :dt3 && ' +
        	dateFieldAPI + ' != :dt4', 
        	binds
    	);
        //System.assertEquals('rkl__Date_Field__c != null AND rkl__Date_Field__c > 2016-02-22 AND rkl__Date_Field__c > 2016-02-23 AND rkl__Date_Field__c != 1969-12-31 AND rkl__Date_Field__c != 2017-05-25', expr.ser());
        System.assertEquals(
        	dateFieldAPI + ' != null AND ' +
        	dateFieldAPI + ' > 2016-02-22 AND ' +
        	dateFieldAPI + ' > 2016-02-23 AND ' +
        	dateFieldAPI + ' != 1969-12-31 AND ' +
        	dateFieldAPI + ' != 2017-05-25', 
        	expr.ser()
    	);

        //p.parseCond('rkl__Date_Field__c between [ 2004-04-04, 2007-04-04T21:30:34Z ]').ser();
        p.parseCond(dateFieldAPI + ' between [ 2004-04-04, 2007-04-04T21:30:34Z ]').ser();
        //p.parseCond('rkl__Date_Field__c between [ TODAY, YESTERDAY ]').ser();
        p.parseCond(dateFieldAPI + ' between [ TODAY, YESTERDAY ]').ser();
        //System.assertEquals('rkl__Date_Field__c >= 2004-04-01 AND rkl__Date_Field__c < 2004-04-04', p.parseCond('rkl__Date_Field__c between ( 2004-04-04, 2004-04-01 ]').ser());
        System.assertEquals(
        	dateFieldAPI + ' >= 2004-04-01 AND ' +
        	dateFieldAPI + ' < 2004-04-04', 
        	p.parseCond(dateFieldAPI + ' between ( 2004-04-04, 2004-04-01 ]').ser()
    	);
        //p.parseCond('rkl__Checkbox_Field__c between [ true, false ]').ser();

        SOQLParser.printValType(true);
        SOQLParser.printValType(System.today());
        SOQLParser.printValType(System.now());
        SOQLParser.printValType(Blob.valueOf('foobar'));
        SOQLParser.printValType(new String[]{});
        SOQLParser.printValType(SOQLParser.P);

        SOQLParser.ReferenceProcessor refProc = new SOQLParser.ReferenceProcessor(p);
        refProc.paramBindLoose()
            .paramBindStrict()
            .paramBindBlind()
            .strictRefs(true)
            .fixNamespaces(false)
            .fixLookupSuffixes(false)
            .rewriter(new SOQLParser.ReferenceRewriter());
    
        //p = new SOQLParser(Schema.rkl__PortalTestObject__c.sObjectType);
        p = new SOQLParser(sObjectType);
        //p.parseCond('rkl__Current_Lookup__r.rkl__TextField__c = "foobar" OR rkl__Text_Area_Field__c = "baz"').processRefs(refProc);
        p.parseCond(
        	lookupFieldAPI_R + '.' + textFieldAPI + ' = "foobar" OR ' +
        	textAreaFieldAPI + ' = "baz"'
    	).processRefs(refProc);
        //p.parseCond('rkl__Current_Lookup__r.rkl__Number_4_Field__c between [1, 42, ]'); // trailing comma should be consumed
        p.parseCond(lookupFieldAPI_R + '.' + numberFieldAPI + ' between [1, 42, ]'); // trailing comma should be consumed
    }

    @isTest
    static void syntaxErrors() {
    	// Resolve test object metadata
    	String dateFieldAPI = qualField('Date__c');
    	String dateTimeFieldAPI = qualField('DateTime__c');
    	String multiSelectFieldAPI = qualField('Picklist_Multiselect__c');
    	String numberFieldAPI = qualField('Number__c');
    	String currencyFieldAPI = qualField('Currency__c');
    	String textFieldAPI = qualField('Text__c');
    	String textAreaFieldAPI = qualField('Text_Area__c');
    	String checkboxFieldAPI = qualField('Checkbox__c');
    	String lookupFieldAPI = qualField('Lookup__c');
    	String lookupFieldAPI_R = lookupFieldAPI.replaceFirst('(?i)__c$', '__r');

    	String[] allFields = new String[]{
    		dateFieldAPI,
    		dateTimeFieldAPI,
    		multiSelectFieldAPI,
    		numberFieldAPI,
    		currencyFieldAPI,
    		textFieldAPI,
    		textAreaFieldAPI,
    		checkboxFieldAPI,
    		lookupFieldAPI
    	};

        //SOQLParser p = new SOQLParser(Schema.rkl__PortalTestObject__c.sObjectType);
        SOQLParser p = new SOQLParser(sObjectType);

        parseErr(p, '(Foo < YESTERDAY', 16, 'Expected matching right parenthesis');
        // expected start of 1st expression:
        parseErr(p, ' (', 2, 'Expected a starting condition');
        // expected start of expression after NOT:
        parseErr(p, 'NOT ', 4, 'Expected a next sub-condition to follow NOT operator');
        // expected start of expression after OR:
        parseErr(p, 'Foo = TODAY OR', 14, 'Expected a next sub-condition to follow OR operator');
        // expected start of expression after AND:
        parseErr(p, 'Foo = TODAY AND ', 16, 'Expected a next sub-condition to follow AND operator');

        parseErr(p, 'Foo = TODAY )', 12, 'Unexpected continuation after whole condition');
        parseErr(p, 'Foo = TODAY #', 12, 'Unexpected error after whole condition');

        parseErr(p, 'NOT NOT Foo = TODAY', 4, 'Chained NOT operators aren\'t allowed');
        parseErr(p, '!Foo = TODAY', 0, 'Unary "!" operator cannot be applied directly to a sub-condition');
        parseErr(p, 'Foo. = TODAY', 5, 'Expected identifier name to follow dot-operator in compound field reference');

        parseErr(p, 'Foo between [[1, 42]]', 13, 'Value-pair cannot be nested inside of a bracket');
        parseErr(p, 'Foo between [, 1, 42]', 13, 'Value-pair cannot start with a leading comma');
        parseErr(p, 'Foo between ?', 12, 'The between operator expects an explicit value-pair or a list of value-pairs');
        parseErr(p, 'Foo between 42', 12, 'The between operator expects an explicit value-pair or a list of value-pairs');
    
        parseErr(p, 'Foo IN (,1,2,3)', 8, 'Value list cannot start with a leading comma');
        parseErr(p, 'Foo IN 42', 7, 'Expected start of a value list expression');

        parseErr(p, 'Foo between [2, :1.2]', 17, 'expected parameter index to be a small integer value');
        parseErr(p, 'Foo between [2, :]', 17, 'expected a parameter name or integer index to follow the colon');

        parseErr(p, 'Foo between ([2, 4],, [8, 16])', 20, 'Consecutive commas in value-pairs list are not allowed');
        parseErr(p, 'Foo between ([2, 4],[8, 16] AND Foo != 8', 28, 'Expected \',\' or \')\' to continue or terminate value-pairs list');

        parseErr(p, 'Foo IN (2,, 4)', 10, 'Consecutive commas in value list are not allowed');
        parseErr(p, 'Foo IN (1, 10 AND Foo != 8', 14, 'Expected \',\' or \')\' to continue or terminate value list');
    }

    static void parseErr(SOQLParser p, String expr, Integer index) {
        parseErr(p, expr, index, null);
    }

    static void parseErr(SOQLParser p, String expr, String errorMsg) {
        parseErr(p, expr, null, errorMsg);
    }

    static void parseErr(SOQLParser p, String expr, Integer index, String errorMsg) {
        SOQLParser.error = null;
        SOQLParser.errorLoc = null;
        SOQLParser.errorHighlights = null;
        Boolean noErr = false;
        try {
            p.parseCond(expr);
            noErr = true;
        } catch (Exception e) {
            if (SOQLParser.error == null) {
                System.assert(false, 'Expected SyntaxError, got unexpected exception: ' + SOQLParser.error.getMessage());
            } else if (!(SOQLParser.error instanceof SOQLParser.ParseException)) {
                System.assert(false, 'Expected SyntaxError, got unexpected ' + SOQLParser.getErrorType(SOQLParser.error) + ': ' + SOQLParser.error.getMessage());
            } else {
                if (errorMsg != null && !SOQLParser.error.getMessage().containsIgnoreCase(errorMsg)) {
                    System.assert(false, 'Expected SyntaxError "' + errorMsg + '"; got error "' + SOQLParser.error.getMessage() + '" at index ' + SOQLParser.errorLoc.index);
                }
                if (index != null && index != SOQLParser.errorLoc.index) {
                    System.assert(false, 'Expected SyntaxError at index ' + index + '; got error at index ' + SOQLParser.errorLoc.index + ': ' + SOQLParser.error.getMessage());
                }
            }
        }
        if (noErr) {
            System.assert(false, 'Expected SyntaxError; no error was thrown');
        }
    }

    static final Schema.sObjectType sObjectType = RKSecurity.resolveSObjectTypeOrThrow('QF_Mock_Object__c');

    static String qualField(String fieldUnqualifiedName) {
		return '' + RKSecurity.resolveFieldOrThrow(sObjectType, fieldUnqualifiedName);
	}
}