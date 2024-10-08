@isTest 
private class AllContactTriggerHandlerTest {
    @isTest
    static void test_chainPointAPI() {
        Account acc = TestUtil.createAccount();
        TestUtil.createContract(acc.Id);
        BCT_Account__c bctAcc = TestUtil.createBctAccount(acc.Id);

        Contact cnt = new Contact(
            FirstName = 'Fir',
            LastName = 'cnt',
            AccountId = acc.Id,
            BC_Tracer_Contact__c = ChainPointContactBatchable.CONTACT_BC_TRACER_YES,
            Gender__c = 'Male',
            Email = 'em@g.com',
            MailingCountry = 'Spain',
            BCT_Interface_Language__c = 'English'
        );
        TriggerManager.accountTrigger.afterInsert = true;
        insert cnt;
        TriggerManager.accountTrigger.afterInsert = false;

        BCP_Contact__c bcpContact = TestUtil.createBctContact(bctAcc.Id,cnt.Id);

        cnt.CP_Create_Contact__c = true;
        Test.startTest();
        update cnt;
        Test.stopTest();
    }

    @isTest
    static void test_chainPointAPIFailure() {

        // Here we don't create the BCP Contact and receive a failure when
        // attempting the sync
        Account acc = TestUtil.createAccount();
        TestUtil.createContract(acc.Id);
        BCT_Account__c bctAcc = TestUtil.createBctAccount(acc.Id);

        Contact cnt = new Contact(
                FirstName = 'Fir',
                LastName = 'cnt',
                AccountId = acc.Id,
                BC_Tracer_Contact__c = ChainPointContactBatchable.CONTACT_BC_TRACER_YES,
                Gender__c = 'Male',
                Email = 'em@g.com',
                MailingCountry = 'Spain',
                BCT_Interface_Language__c = 'English'
        );
        TriggerManager.accountTrigger.afterInsert = true;
        insert cnt;
        TriggerManager.accountTrigger.afterInsert = false;

        cnt.CP_Create_Contact__c = true;
        Test.startTest();

        try {
            update cnt;
        }
        catch (System.DMLException e) {
            System.assertEquals(Label.Contact_Missing_BCP_Contact,e.getDmlMessage(0));
        }
        Test.stopTest();
    }
}