/*
*************************************************************************
CREATED BY : Jason Bradley
CREATED DATE : August 12, 2019
DESCRIPTION : RKSecurity - Test class
	The purpose of this class is primarily to ensure that we have met the
	minimum apex class coverage requirements. RKSecurity is used extensively
	by all of our components, and is already indirectly tested for
	correctness by those components, so there is no need for extensive
	validation in this class.
ORIGINAL TICKET : All RKUX tickets
-------------------------------------------------------------------------
MOD LOG
AUTHOR: 
DATE : 
TICKET : 
DESCRIPTION : 
-------------------------------------------------------------------------
*************************************************************************
*/
@IsTest
private class RKSecurity_Test {
	@isTest
	private static void test_RKSecurity1() {
		String testObjectType = '' + Schema.RKUX_Mock_Object__c.sObjectType;
		RecordType testRecordType = [SELECT Id, DeveloperName FROM RecordType WHERE sObjectType =: testObjectType LIMIT 1];

		RKSecurity.getOrgNamespace();

		RKSecurity.setSecurityMode(RKSecurity.ALL_OR_NONE);
		RKSecurity.assertReadable(Schema.RKUX_Mock_Object__c.sObjectType, 'Text__c');

		RKUX_Mock_Object__c testRecord = new RKUX_Mock_Object__c(Text__c = 'TEST');
		RKSecurity.safeInsert(testRecord);
		RKSecurity.safeDelete(testRecord);

		RKUX_Mock_Object__c lookupTarget = new RKUX_Mock_Object__c();
		insert lookupTarget;

		testRecord = new RKUX_Mock_Object__c(
			Text__c = 'TEST',
			RecordTypeId = testRecordType.Id,
			Date__c = System.today(),
			Checkbox__c = true,
			Number__c = 123.0,
			Lookup__c = lookupTarget.Id
		);
		Map<String, Object> filteredSObject = RKSecurity.filterSObject(testRecord);
		filteredSObject.put('sobjectType', testObjectType);
		RKSecurity.Deserializer deserializer = RKSecurity.deserialize(JSON.serialize(filteredSObject), Schema.RKUX_Mock_Object__c.sObjectType);
		deserializer.doSafeInsert();

		RKSecurity.safeInsert(testRecord);
		deserializer = RKSecurity.deserialize(JSON.serialize(RKSecurity.filterSObject(testRecord)), Schema.RKUX_Mock_Object__c.sObjectType);
		deserializer.doSafeUpdate();

		testRecord = new RKUX_Mock_Object__c(
			Text__c = 'TEST',
			RecordTypeId = testRecordType.Id,
			Date__c = System.today(),
			Checkbox__c = true,
			Number__c = 123.0,
			Lookup__c = lookupTarget.Id
		);
		insert testRecord;
		testRecord = [SELECT Text__c, Date__c, Checkbox__c, Number__c, RecordType.DeveloperName, Lookup__c, Lookup__r.Text__c, Lookup__r.Date__c FROM RKUX_Mock_Object__c WHERE Id =: testRecord.Id];
		RKSecurity.filterSObject(testRecord);

		testRecord = [SELECT Id, (SELECT Text__c FROM Lookup_Children__r) FROM RKUX_Mock_Object__c WHERE Id =: testRecord.Lookup__c];
		RKSecurity.filterSObject(testRecord);

		testRecord = new RKUX_Mock_Object__c(Text__c = 'TEST');
		RKSecurity.sharingOffOneTime();
		deserializer = RKSecurity.deserialize(JSON.serialize(RKSecurity.filterSObject(testRecord)), Schema.RKUX_Mock_Object__c.sObjectType);
		deserializer.doSafeInsert();

		RKSecurity.safeInsert(testRecord);
		deserializer = RKSecurity.deserialize(JSON.serialize(RKSecurity.filterSObject(testRecord)), Schema.RKUX_Mock_Object__c.sObjectType);
		deserializer.doSafeUpdate();

		//testRecord.Number__c = 144.0;
        //deserializer = RKSecurity.deserialize(JSON.serialize(RKSecurity.filterSObject(testRecord)), Schema.RKUX_Mock_Object__c.sObjectType);
        //deserializer.doSafeUpsert();

		deserializer.toSafeReadable();
		deserializer.toSystemReadable();
		deserializer.toSystemReadables();

		RKUX_Mock_Object__c[] testRecords = new RKUX_Mock_Object__c[]{
			new RKUX_Mock_Object__c(Text__c = 'TEST'),
			new RKUX_Mock_Object__c(Text__c = 'TEST2')
		};
		deserializer = RKSecurity.deserialize(JSON.serialize(RKSecurity.filterSObject(testRecords)), Schema.RKUX_Mock_Object__c.sObjectType);

		Vobj.SchemaDesc V = Vobj.getSchema(VobjBindings.class);
		Vobj.ObjectDesc Claim = V.obj('Claim');
		Vobj.ObjectDesc Occurrence = V.obj('Occurrence');

		Vobj.Record testOccurrence = Occurrence.newRecord(new Map<String, Object> {
			'coverageMajor' => 'TEST'
		});
		Vobj.upserts(new Vobj.Record[]{testOccurrence});

		Vobj.Record testClaim = Claim.newRecord(new Map<String, Object> {
			'coverageMajor' => 'TEST',
			'status' => 'TEST',
			'currencyCode' => 'USD',
			'occurrenceId' => testOccurrence.Id,
			'selfAdministered' => false,
			'dateClosed' => System.today()
		});
		Vobj.upserts(new Vobj.Record[]{testClaim});

		testClaim = V.query('SELECT ' +
			Claim.selects('selfAdministered, dateClosed, coverageMajor, expensePaid, status, currencyCode, occurrence.coverageMajor') +
			' FROM ' + Claim + ' WHERE Id = \'' + testClaim.Id + '\''
		)[0];

		RKSecurity.get(testClaim.obj, Claim.path('occurrence.coverageMajor').strict);

		deserializer = RKSecurity.deserialize(JSON.serialize(testClaim.obj.getPopulatedFieldsAsMap()), Claim.objType);

		RKSecurity.getSafePath(Schema.RKUX_Mock_Object__c.sObjectType, 'Lookup__r.Text__c');
		//RKSecurity.PathPart testPath = RKSecurity.getPathMeta(Schema.RKUX_Mock_Object__c.sObjectType, 'Lookup__r.Text__c');
		RKSecurity.PathPart testPath = RKSecurity.getPathMeta('Lookup__r.Text__c', '' + Schema.RKUX_Mock_Object__c.sObjectType);
		Object val = testPath.isCompound;
		val = testPath.terminatingPart;
		val = testPath.safeAccessPath;

		val = testPath.getValue(testRecord, false);

		RKSecurity.getAllPaths(new RKSecurity.PathPart[]{testPath});
		RKSecurity.getSystemAccessPath(testPath);

		RKSecurity.safeSelect('' + Schema.RKUX_Mock_Object__c.sObjectType, 'Text__c');
		RKSecurity.safeSelect('' + Schema.RKUX_Mock_Object__c.sObjectType, new String[]{'Text__c'});
		RKSecurity.safeSelect(Schema.RKUX_Mock_Object__c.sObjectType, 'Text__c');
		RKSecurity.safeSelect(Schema.RKUX_Mock_Object__c.sObjectType, new String[]{'Text__c'}, null);

		assertUnorderedStringListEquals(String.join(
			new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c
			}, ','),
			RKSecurity.systemSelect('' + Schema.RKUX_Mock_Object__c.sObjectType, 'Text__c')
		);
		
		assertUnorderedStringListEquals(String.join(
			new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c
			}, ','),
			RKSecurity.systemSelect('' + Schema.RKUX_Mock_Object__c.sObjectType, new String[]{'Text__c'})
		);
		
		assertUnorderedStringListEquals(String.join(
			new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c
			}, ','),
			RKSecurity.systemSelect(Schema.RKUX_Mock_Object__c.sObjectType, 'Text__c')
		);
		assertUnorderedStringListEquals(String.join(
			new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c
			}, ','),
			RKSecurity.systemSelect(Schema.RKUX_Mock_Object__c.sObjectType, new String[]{'Text__c'}, null)
		);

		RKSecurity.resolveRecordType(Schema.RKUX_Mock_Object__c.sObjectType, 'I');
		RKSecurity.resolveFieldSet(Schema.RKUX_Mock_Object__c.sObjectType, 'Test_DerivedRecords_Source');

		assertUnorderedStringListEquals(String.join(
			new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c,
				'' + Schema.RKUX_Mock_Object__c.fields.Lookup__c,
				'' + Schema.RKUX_Mock_Object__c.fields.Date__c
			}, ','),
			RKSecurity.joinSelect('' + Schema.RKUX_Mock_Object__c.fields.Text__c + ', ' + Schema.RKUX_Mock_Object__c.fields.Lookup__c, '' + Schema.RKUX_Mock_Object__c.fields.Date__c)
		);
	}

	@IsTest
	private static void test_RKSecurity_Access() {
		try {
			RKSecurity.checkCRUD(Schema.RKUX_Mock_Object__c.sObjectType);
		} catch (RKSecurity.ReferenceException e) {}

		try {
			RKSecurity.assertReadable(Schema.RKUX_Mock_Object__c.sObjectType);
		} catch (RKSecurity.ReferenceException e) {}

		try {
			RKSecurity.assertReadable('' + Schema.RKUX_Mock_Object__c.sObjectType);
		} catch (RKSecurity.ReferenceException e) {}

		try {
			RKSecurity.assertReadable(Schema.RKUX_Mock_Object__c.sObjectType, '' + Schema.RKUX_Mock_Object__c.fields.Date__c);
		} catch (RKSecurity.ReferenceException e) {}

		try {
			RKSecurity.assertReadable('' + Schema.RKUX_Mock_Object__c.sObjectType, '' + Schema.RKUX_Mock_Object__c.fields.Date__c);
		} catch (RKSecurity.ReferenceException e) {}

		try {
			RKSecurity.assertReadable(Schema.RKUX_Mock_Object__c.sObjectType, new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c,
				'' + Schema.RKUX_Mock_Object__c.fields.Date__c
			});
		} catch (RKSecurity.ReferenceException e) {}

		try {
			RKSecurity.assertReadable('' + Schema.RKUX_Mock_Object__c.sObjectType, new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c,
				'' + Schema.RKUX_Mock_Object__c.fields.Date__c
			});
		} catch (RKSecurity.ReferenceException e) {}
	}

	@IsTest
	private static void test_RKSecurity_Logging() {
		Schema.SObjectType testSObjectType = Schema.RKUX_Mock_Object__c.sObjectType;
		Schema.SObjectField testSObjectField = Schema.RKUX_Mock_Object__c.fields.Text__c;
		RKSecurity.logSecurityMiss(testSObjectType, RKSecurity.ACCESS_READ);
		RKSecurity.logSecurityMiss(testSObjectType, testSObjectField, RKSecurity.ACCESS_READ);
		RKSecurity.printAccess(RKSecurity.ACCESS_CREATE | RKSecurity.ACCESS_READ | RKSecurity.ACCESS_UPDATE | RKSecurity.ACCESS_DELETE);
	}

	@IsTest
	private static void test_RKSecurity_APIBinding() {
		RKSecurity.resolvePrimitiveBindTypes(RKSecurity.BIND_PGK_STATIC_THEN_DYNAMIC);
		RKSecurity.resolvePrimitiveBindTypes(RKSecurity.BIND_ORG_STATIC_THEN_DYNAMIC);
		RKSecurity.resolvePrimitiveBindTypes(RKSecurity.BIND_DYNAMIC_THEN_PKG_STATIC);
		RKSecurity.resolvePrimitiveBindTypes(RKSecurity.BIND_DYNAMIC_THEN_ORG_STATIC);
		RKSecurity.resolvePrimitiveBindTypes(RKSecurity.BIND_DYNAMIC);

		RKSecurity.startBinding(RKSecurity.BIND_DYNAMIC);
		RKSecurity.startBinding(RKSecurity.BIND_DYNAMIC_THEN_ORG_STATIC);
		RKSecurity.revertBinding();
		RKSecurity.revertToDefaultBinding();
	}

	private static void assertUnorderedStringListEquals(String list1, String list2) {
		Set<String> list1Items = new Set<String>(list1.replaceAll('\\s++', '').split(',')),
			list2Items = new Set<String>(list2.replaceAll('\\s++', '').split(','));

		System.assert(list1Items.equals(list2Items), 'Expected: [' + list1 + '], Got: [' + list2 + ']');
	}

    // Added by Manisha w.r.t RKDEV-43045
    @IsTest
    private static void test_RKSecurity2() {
        Boolean caught = false;
        //This throws RKSecurity.ReferenceException: Invalid Child Relationship Field [Account] on Object Contact
        try {
            RKSecurity.resolveChildRelOrThrow(Schema.Contact.sObjectType, 'Account.Id') ;
        } catch (Exception ae) {
            caught = true;
        }
        System.assert(caught, 'Expected Invalid Child Relationship Field');
    }

    @IsTest
    private static void test_RKSecurity3() {
        //RKSecurity.resolveChildRelFromLookupOrThrow(Schema.RKUX_Mock_Object__c.sObjectType, 'Lookup__c');
        //RKSecurity.resolveChildRelFromLookup(Schema.RKUX_Mock_Object__c.sObjectType, 'Lookup__c');
        RKSecurity.PoundDecorator p = new RKSecurity.PoundDecorator();
        p.decorate('');
        RKSecurity.QuoteDecorator q = new RKSecurity.QuoteDecorator();
        q.decorate('');
        RKSecurity.NumberedRowResolver n = new RKSecurity.NumberedRowResolver(null);
        Boolean caught = false;
        //This throws error System.NullPointerException: Attempt to de-reference a null object
        try {
            n.getRowLabels(null);
        } catch (Exception ae) {
            caught = true;
        }
        System.assert(caught, 'Expected Attempt to de-reference a null object');
        sObject[] s = new sObject[]{};
            RKSecurity.NamedInsertRowResolver nmd = new RKSecurity.NamedInsertRowResolver(s, '');
        caught = false;
        //This throws error System.NullPointerException: Attempt to de-reference a null object
        try {
            nmd.getRowLabels(null);
        } catch (Exception ae) {
            caught = true;
        }
        System.assert(caught, 'Expected Attempt to de-reference a null object');
        RKSecurity.NamedUpdateRowResolver nmu = new RKSecurity.NamedUpdateRowResolver(s, '');
        nmu.doQuery(true);
        caught = false;
        //This throws error System.NullPointerException: Attempt to de-reference a null object
        try {
            nmu.getRowLabels(null);
        } catch (Exception ae) {
            caught = true;
        }
        System.assert(caught, 'Expected Attempt to de-reference a null object');
    }

    @IsTest
    private static void test_RKSecurity4() {
        RKSecurity.systemSelect('Contact', 'Name', RKSecurity.BIND_PGK_STATIC_THEN_DYNAMIC);
        RKSecurity.isReadable(Schema.Account.sObjectType);
        RKSecurity.isReadable('Account');
        RKSecurity.resolveFieldSetOrThrow(Schema.RKUX_Mock_Object__c.sObjectType, 'Checklist');
        RKSecurity.resolveFieldDescOrThrow(Schema.RKUX_Mock_Object__c.sObjectType, 'Lookup__c');

        Boolean caught = false;
        // We expect this to fail because the required Name field is not provided to Account record
        try {
            RKSecurity.safeInsert(new Account());
        } catch (AuraHandledException ae) {
            caught = true;
        }
        System.assert(caught, 'Expected insert failure for missing required Name field');
        RKSecurity.Deserializer deser;
        RKUX_Mock_Object__c mock = new RKUX_Mock_Object__c(Date__c = System.today());
        RKSecurity.sharingOff();
        RKSecurity.sharingOffOneTime();
        RKSecurity.safeInsert(mock);
        String ser = JSON.serialize(RKSecurity.filterSObject(new RKUX_Mock_Object__c[]{ mock }));
        deser = RKSecurity.deserialize(ser);
        deser.toSafeReadable();

        RKSecurity.sharingOffOneTime();
        RKSecurity.safeDelete(mock);
    }

    @isTest
    private static void test_RKSecurity5() {
        Boolean caught = false;
        //This throws System.AuraHandledException: Script-thrown exception
        try {
            RKSecurity.bindTypeInvalidErr(2);
        } catch (AuraHandledException ae) {
            caught = true;
        }
        System.assert(caught, 'Expected Script-thrown exception');
        RKSecurity.resetSecurityLog();
        RKSecurity.transactionalThrow();
        RKSecurity.throwSecurityViolations();
        RKSecurity.systemSelect('Contact', 'Name', RKSecurity.BIND_PGK_STATIC_THEN_DYNAMIC);
        RKSecurity.systemSelect(Schema.Contact.sObjectType, new List<String>{'Name'}, RKSecurity.BIND_PGK_STATIC_THEN_DYNAMIC);
    }

    @IsTest
    private static void test_RKSecurity6() {
        RKSecurity.printAccess(1);
        RKSecurity.setSecurityMode(RKSecurity.ALL_OR_NONE);
        Schema.DescribeFieldResult F = Contact.Name.getDescribe();
        Boolean caught = false;
        //This throws System.AuraHandledException: Missing access for Object Contact field: Name [Create]
        try {
            RKSecurity.logSecurityMiss(Schema.Contact.sObjectType, F.getSObjectField(), 2);
            RKSecurity.throwSecurityViolations();
        //} catch (AuraHandledException ae) {
		} catch (SOQLContext.AccessException ae) {
            caught = true;
        }
        System.assert(caught, 'Expected Missing access for Object Contact field: Name [Create]');

        try {
			//RKSecurity.assertCreateable(Schema.RKUX_Mock_Object__c.sObjectType, '' + Schema.RKUX_Mock_Object__c.fields.Date__c);
			RKSecurity.assertReadable(Schema.RKUX_Mock_Object__c.sObjectType, '' + Schema.RKUX_Mock_Object__c.fields.Date__c);
		//} catch (RKSecurity.ReferenceException e) {}
		} catch (SOQLContext.AccessException ae) {}

		try {
			//RKSecurity.assertCreateable(Schema.RKUX_Mock_Object__c.sObjectType, new String[]{{
			RKSecurity.assertReadable(Schema.RKUX_Mock_Object__c.sObjectType, new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c,
				'' + Schema.RKUX_Mock_Object__c.fields.Date__c
			});
		} catch (SOQLContext.AccessException e) {}

		try {
			//RKSecurity.assertCreateable('' + Schema.RKUX_Mock_Object__c.sObjectType, new String[]{
			RKSecurity.assertReadable('' + Schema.RKUX_Mock_Object__c.sObjectType, new String[]{
				'' + Schema.RKUX_Mock_Object__c.fields.Text__c,
				'' + Schema.RKUX_Mock_Object__c.fields.Date__c
			});
		} catch (SOQLContext.AccessException e) {}
    }

}