@IsTest
private class AllContactTriggerHandlerCreateUsersTest {

    // Test where Account Membership Category is 'Associate Member' and Primary Contact;
    @IsTest
    private static void testAssociateMember() {
        Account acc = new Account();
        acc.Member_Status__c = 'Member';
        acc.Membership__c = true;
        acc.myBetterCotton_Access__c = false;
        acc.Name = 'accName';
        acc.Producer_Unit__c = false;
        acc.ShippingCountry = 'United Kingdom';
        acc.Account_Type__c = AccountTriggerHandler.TYPE_BCT_USER_ONLY;
        acc.Membership_Category__c = 'Associate Member';
        insert acc;

        Contract lstContract = new Contract(
                AccountId = acc.Id,
                Validity_Start_Date__c = Date.today().addDays(30),
                Exclude_from_Renewal_Cycle__c = false,
                Membership_Category__c = 'Associate Member',
                Membership_Renewal_Date__c = Date.today().addDays(30)
        );
        insert lstContract;

        lstContract.Status = 'Activated';
        update lstContract;

        Opportunity opp = new Opportunity();
        opp.AccountId = acc.Id;
        opp.Name = 'testoppo1123';
        opp.CloseDate = System.today();
        opp.Payment_Received_Date__c = System.today();
        opp.StageName = 'Closed Won';
        opp.Validity_Start_Date__c =  System.today().addYears(1);
        opp.Contract = lstContract;
        opp.Membership_Category__c = 'Suppliers and Manufacturers - Other Intermediaries';
        opp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Application').getRecordTypeId();
        opp.CurrencyIsoCode = 'EUR';
        insert opp;

        Contact con = new Contact(
                FirstName = 'Fir',
                LastName = 'cnt',
                AccountId = acc.Id,
                BC_Tracer_Contact__c = ChainPointContactBatchable.CONTACT_BC_TRACER_YES,
                Gender__c = 'Male',
                Email = 'em@g.com',
                MailingCountry = 'Spain',
                BCT_Interface_Language__c = 'English',
                Primary_Contact__c = 'Yes'
        );

        // Fire the contact trigger to run the user creation
        Test.startTest();
        insert con;
        Test.stopTest();

        // Show we have a user
        List<User> users = [SELECT Id,Profile.Name FROM User WHERE ContactId = :con.Id];
        Assert.areEqual(users.size(),1);
        Assert.areEqual('AM Plus Login User - My Better Cotton',users.get(0).Profile.Name);

        List<PermissionSetAssignment> permSetAssignments = [SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = :users.get(0).Id];
        Assert.areEqual('MyBetterCotton_Primary_User',permSetAssignments.get(0).PermissionSet.Name);
    }

    @IsTest
    private static void testCivilSociety() {
        Account acc = new Account();
        acc.Member_Status__c = 'Member';
        acc.Membership__c = true;
        acc.myBetterCotton_Access__c = false;
        acc.Name = 'accName';
        acc.Producer_Unit__c = false;
        acc.ShippingCountry = 'United Kingdom';
        acc.Account_Type__c = AccountTriggerHandler.TYPE_BCT_USER_ONLY;
        acc.Membership_Category__c = 'Civil Society';
        insert acc;

        Contract lstContract = new Contract(
                AccountId = acc.Id,
                Validity_Start_Date__c = Date.today().addDays(30),
                Exclude_from_Renewal_Cycle__c = false,
                Membership_Category__c = 'Associate Member',
                Membership_Renewal_Date__c = Date.today().addDays(30)
        );
        insert lstContract;

        lstContract.Status = 'Activated';
        update lstContract;

        Opportunity opp = new Opportunity();
        opp.AccountId = acc.Id;
        opp.Name = 'testoppo1123';
        opp.CloseDate = System.today();
        opp.Payment_Received_Date__c = System.today();
        opp.StageName = 'Closed Won';
        opp.Validity_Start_Date__c =  System.today().addYears(1);
        opp.Contract = lstContract;
        opp.Membership_Category__c = 'Suppliers and Manufacturers - Other Intermediaries';
        opp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Application').getRecordTypeId();
        opp.CurrencyIsoCode = 'EUR';
        insert opp;

        Contact con = new Contact(
                FirstName = 'Fir',
                LastName = 'cnt',
                AccountId = acc.Id,
                BC_Tracer_Contact__c = ChainPointContactBatchable.CONTACT_BC_TRACER_YES,
                Gender__c = 'Male',
                Email = 'em@g.com',
                MailingCountry = 'Spain',
                BCT_Interface_Language__c = 'English',
                Primary_Contact__c = 'Yes'
        );

        // Fire the contact trigger to run the user creation
        Test.startTest();
        insert con;
        Test.stopTest();

        // Show we have a user
        List<User> users = [SELECT Id,Profile.Name FROM User WHERE ContactId = :con.Id];
        Assert.areEqual(users.size(),1);
        Assert.areEqual('CS Community Plus Login User - My Better Cotton',users.get(0).Profile.Name);

        List<PermissionSetAssignment> permSetAssignments = [SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = :users.get(0).Id];
        Assert.areEqual('MyBetterCotton_Primary_User',permSetAssignments.get(0).PermissionSet.Name);
    }

    @IsTest
    private static void testSecondaryContact() {
        Account acc = new Account();
        acc.Member_Status__c = 'Member';
        acc.Membership__c = true;
        acc.myBetterCotton_Access__c = false;
        acc.Name = 'accName';
        acc.Producer_Unit__c = false;
        acc.ShippingCountry = 'United Kingdom';
        acc.Account_Type__c = AccountTriggerHandler.TYPE_BCT_USER_ONLY;
        acc.Membership_Category__c = 'Civil Society';
        insert acc;

        Contract lstContract = new Contract(
                AccountId = acc.Id,
                Validity_Start_Date__c = Date.today().addDays(30),
                Exclude_from_Renewal_Cycle__c = false,
                Membership_Category__c = 'Associate Member',
                Membership_Renewal_Date__c = Date.today().addDays(30)
        );
        insert lstContract;

        lstContract.Status = 'Activated';
        update lstContract;

        Opportunity opp = new Opportunity();
        opp.AccountId = acc.Id;
        opp.Name = 'testoppo1123';
        opp.CloseDate = System.today();
        opp.Payment_Received_Date__c = System.today();
        opp.StageName = 'Closed Won';
        opp.Validity_Start_Date__c =  System.today().addYears(1);
        opp.Contract = lstContract;
        opp.Membership_Category__c = 'Suppliers and Manufacturers - Other Intermediaries';
        opp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Application').getRecordTypeId();
        opp.CurrencyIsoCode = 'EUR';
        insert opp;

        Contact con = new Contact(
                FirstName = 'Fir',
                LastName = 'cnt',
                AccountId = acc.Id,
                BC_Tracer_Contact__c = ChainPointContactBatchable.CONTACT_BC_TRACER_YES,
                Gender__c = 'Male',
                Email = 'em@g.com',
                MailingCountry = 'Spain',
                BCT_Interface_Language__c = 'English',
                Primary_Contact__c = 'No'
        );

        // Fire the contact trigger to run the user creation
        Test.startTest();
        insert con;
        Test.stopTest();

        // Show we do not have a user
        List<User> users = [SELECT Id,Profile.Name FROM User WHERE ContactId = :con.Id];
        Assert.areEqual(users.size(),0);
    }
}