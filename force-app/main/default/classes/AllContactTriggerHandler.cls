public class AllContactTriggerHandler {
	//This method gets the records from the trigger
	//@param:(List of Contact Records)
	public void chainpointApi(List<Contact> contactList) {

		// Get the set of contact ids so we can query against them
		Set<Id> contactIdSet = new Map<Id,Contact>(contactList).keySet();

		// Get BCP contact records for these contacts because we can
		// only process these contacts if a BCP contact exists for them
		Set<Id> contactsWithBcpContact = new Set<Id>();
		for (BCP_Contact__c bcpContact : [SELECT Id, Contact__c FROM BCP_Contact__c WHERE Contact__c IN :contactIdSet]) {
			contactsWithBcpContact.add(bcpContact.Contact__c);
		}

		List<Id> contactIds = new List<Id>();
		//get the record from trigger and pass the id of record to chainpoint controller
		for (Contact contact : contactList) {
            if (contact.CP_Create_Contact__c || contact.CP_Update_Contact__c || contact.CP_Deactivate_Contact__c) {

				// Only add if the contact id exists as a BCP contact
				if (contactsWithBcpContact.contains(contact.Id)) {
					contactIds.add(contact.Id);
				}
				else {
					contact.addError(Label.Contact_Missing_BCP_Contact);
				}
            }
		}
		TriggerManager.accountTrigger.afterInsert = true;

		// Only call if we have contact ids to process
        if (!contactIds.isEmpty()) ChainPointContactBatchable.launchByContacts(contactIds);
	}
}