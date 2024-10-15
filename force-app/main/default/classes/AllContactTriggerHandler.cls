public class AllContactTriggerHandler {

	// PT (SJ) 7 Oct - Literals for Membership Categories
	private static final String RETAILER_AND_BRAND = 'Retailer and Brand';
	private static final String SM_OTHER = 'Suppliers and Manufacturers - Other Intermediaries';
	private static final String SM_FIN_INST = 'Suppliers and Manufacturers - Financial Institutions';
	private static final String SM_TRADERS = 'Suppliers and Manufacturers - Traders';
	private static final String PRODUCER_ORG = 'Producer Organisation';
	private static final String ASSOC_MEMBER = 'Associate Member';
	private static final String CIVIL_SOCIETY = 'Civil Society';

	// PT (SJ) 7 Oct - Literals for Profiles
	private static final String CUSTOMER_COMMUNITY_PLUS_LOGIN_USER = 'Customer Community Plus Login User - My Better Cotton';
	private static final String SM_COMMUNITY_PLUS_LOGIN_USER = 'SM Community Plus Login User - My Better Cotton';
	private static final String PO_COMMUNITY_PLUS_LOGIN_USER = 'PO Community Plus Login User - My Better Cotton';
	private static final String AM_PLUS_LOGIN_USER =  'AM Plus Login User - My Better Cotton';
	private static final String CS_COMMUNITY_PLUS = 'CS Community Plus Login User - My Better Cotton';

	// PT (SJ) 7 Oct - Map of Membership Category to User Profile to use for created users
	private static final Map<String, String> MEMBERSHIP_CATEGORY_TO_PROFILE = new Map<String,String>{
			RETAILER_AND_BRAND => CUSTOMER_COMMUNITY_PLUS_LOGIN_USER,
			SM_OTHER => SM_COMMUNITY_PLUS_LOGIN_USER,
			SM_FIN_INST => SM_COMMUNITY_PLUS_LOGIN_USER,
			SM_TRADERS => SM_COMMUNITY_PLUS_LOGIN_USER,
			PRODUCER_ORG => PO_COMMUNITY_PLUS_LOGIN_USER,
			ASSOC_MEMBER => AM_PLUS_LOGIN_USER,
			CIVIL_SOCIETY => CS_COMMUNITY_PLUS
	};

	// PT (SJ) 7 Oct 2024 - Maps type of user ('Yes' is Primary and 'No' is Secondary) to a mapping of membership category
	// to list of permission sets to assign.
	// Note that secondary 'No' entries are here for completeness and future expansion.  At the time of writing only
	// primary contacts are being processed automatically
	private static final Map<String,Map<String,List<String>>> PERM_SET_ASSIGNMENT = new Map<String,Map<String,List<String>>>{
			'Yes' => new Map<String,List<String>>{
					RETAILER_AND_BRAND => new List<String>{'MyBetterCotton_Primary_User'},
					SM_OTHER => new List<String>{'MyBetterCotton_Primary_User'},
					SM_FIN_INST => new List<String>{'MyBetterCotton_Primary_User'},
					SM_TRADERS => new List<String>{'MyBetterCotton_Primary_User'},
					PRODUCER_ORG => new List<String>{'MyBetterCotton_Primary_User'},
					ASSOC_MEMBER => new List<String>{'MyBetterCotton_Primary_User'},
					CIVIL_SOCIETY => new List<String>{'MyBetterCotton_Primary_User'}
			},
			'No' => new Map<String,List<String>>{
					RETAILER_AND_BRAND => new List<String>{'MyBetterCotton_Secondary_User'},
					SM_OTHER => new List<String>{'MyBetterCotton_Secondary_User'},
					SM_FIN_INST => new List<String>{'MyBetterCotton_Secondary_User'},
					SM_TRADERS => new List<String>{'MyBetterCotton_Secondary_User'},
					PRODUCER_ORG => new List<String>{'MyBetterCotton_Secondary_User'},
					ASSOC_MEMBER => new List<String>{'MyBetterCotton_Secondary_User'},
					CIVIL_SOCIETY => new List<String>{'MyBetterCotton_Secondary_User'}
			}
	}; // end permission set map

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

	public class OnAfterInsertQueueable implements Queueable {
		private final Map<Id,Contact> newContactsMap;
		public OnAfterInsertQueueable(Map<Id,Contact> pNewContactsMap) {
			this.newContactsMap = pNewContactsMap;
		}
		public void execute(QueueableContext context) {
			AllContactTriggerHandler.createUserRecords(this.newContactsMap);
		}
	} // end OnAfterInsert

	public static void onAfterInsert(Map<Id,Contact> newContactsMap) {

		// PT (SJ) 14 Oct 2024 - had to move into queueable to disassociate contact changes
		// from user permissions which gave a MIXED DML error.
		OnAfterInsertQueueable ofiq = new OnAfterInsertQueueable(newContactsMap);
		System.enqueueJob(ofiq);
	} // end OnAfterInsert

	// Called in queueable context to create the users and assign profiles and permission sets
	public static void createUserRecords(Map<Id,Contact> newContactsMap) {

		System.debug('createUserRecords with contacts ' + newContactsMap);

		// Collect account ids so we can access the related opportunities
		Set<Id> parentAccountIds = new Set<Id>();

		// Maintain a map of primary contacts - we filter out the others
		Map<Id,Contact> primaryContactsMap = new Map<Id,Contact>();

		// Filter out non primary contacts
		for (Contact newContact : newContactsMap.values()) {

			// Only interested in Primary Contacts
			if (newContact.Primary_Contact__c == 'Yes') {
				primaryContactsMap.put(newContact.Id,newContact);
				parentAccountIds.add(newContact.AccountId);
			} // end primary contact check if
		} // end loop through contacts

		System.debug('Primary contacts ' + primaryContactsMap);

		// Continue only if we have primary contacts
		if (!primaryContactsMap.isEmpty()) {

			// Map to store the account id to the latest opportunity that matches the membership criteria
			Map<Id,Opportunity> accountIdToOpportunity = new Map<Id,Opportunity>();

			// Query in Opportunities.  Query is based on the myBC - Create User Access report
			// Ordering in ascending last modified date.  So if 2 opps appear for the same account, we will use the most recent.
			for (Opportunity oppWithAccess : [SELECT Id, AccountId, Account.Name, Account.Contract_Start_Date__c, Account.Membership_Category__c FROM Opportunity WHERE StageName = 'Closed Won' AND RecordType.Name IN ('Application','RB Recruitment') AND Membership_Category__c IN ('Suppliers and Manufacturers - Other Intermediaries', 'Suppliers and Manufacturers - Traders', 'Retailers and Brands') AND Account.Member_Status__c = 'Member' AND Account.Membership__c = TRUE AND Account.myBetterCotton_Access__c = FALSE AND AccountId IN :parentAccountIds ORDER BY LastModifiedDate ASC]) {
				accountIdToOpportunity.put(oppWithAccess.AccountId,oppWithAccess);
			} // end loop through opportunities

			System.debug('account id to opportunity ' + accountIdToOpportunity);

			// Continue if we have any matching records and need to create user records
			if (!accountIdToOpportunity.isEmpty()) {

				// We will need profile ids to create the users
				Map<String,Id> profileNameToId = new Map<String,Id>();
				for (Profile prof : [SELECT Id, Name FROM Profile WHERE Name IN :MEMBERSHIP_CATEGORY_TO_PROFILE.values()]) {
					profileNameToId.put(prof.Name,prof.Id);
				} // end loop through profiles

				System.debug('profile = ' + profileNameToId);

				List<User> usersToCreate = new List<User>();

				// These options cause the email to go out on creation of the user
				Database.DMLOptions dmo = new Database.DMLOptions();
				dmo.emailHeader.triggerUserEmail = true;
				dmo.optAllOrNone = false;

				// Go back through the contacts and determine if it should be created
				for (Contact newContact : primaryContactsMap.values()) {
					Opportunity correspondingOpp = accountIdToOpportunity.get(newContact.AccountId);
					if (correspondingOpp == null) {
						System.debug('No corresponding Opportunity found for contact - not creating user record' + newContact);
					} // found matching opportunity if
					else {

						// First get the profile Id
						String profileName = MEMBERSHIP_CATEGORY_TO_PROFILE.get(correspondingOpp.Account.Membership_Category__c);
						if (profileName == null) {
							System.debug('Profile not found for membership category of ' + correspondingOpp.Account.Membership_Category__c);
						}
						else {

							Id profileId = profileNameToId.get(profileName);
							if (profileId == null) {
								System.debug('Profile misconfiguration = could not file profile id for name ' + profileName);
							}
							else {

								String alias = newContact.FirstName + newContact.LastName;
								if (alias.length() > 8) alias = alias.substring(0,8);

								User communityUser = new User(
										FirstName = newContact.FirstName,
										LastName = newContact.LastName,
										Email = newContact.Email,
										ContactId = newContact.Id,
										ProfileId = profileId,
										Username = newContact.Email,
										Alias = alias,
										CommunityNickname = 'User' + newContact.Id,
										TimeZoneSidKey = 'Europe/London',
										LocaleSidKey = 'en_GB',
										EmailEncodingKey = 'UTF-8',
										LanguageLocaleKey = 'en_US');
								communityUser.setOptions(dmo);
								usersToCreate.add(communityUser);

								System.debug('Added user ' + communityUser);
							} // end profile id not found for name else
						} // end profile name found check else
					} // found matching opportunity else
				} // end loop through primary contacts

				// Create the user records if we have any!
				if (!usersToCreate.isEmpty()) {
					System.debug('Attempting to create users ' + usersToCreate);
					List<Database.SaveResult> results = Database.insert(usersToCreate);
					System.debug('Results ' + results);

					// Capture successful user records for adding permission sets to later on
					Map<Id,User> contactIdToCreatedUsers = new Map<Id,User>();
					for (Database.SaveResult result : results) {
						if (result.isSuccess()) {
							for (User createdUser : usersToCreate) {
								if (createdUser.Id == result.getId()) {
									contactIdToCreatedUsers.put(createdUser.ContactId, createdUser);
									break;
								} // end found match between users created and save result id
							} // end loop through the user created list
						} // end check for this user created successfully if
					} // end loop through create results

					// Process permission sets if we have a successful create
					if (!contactIdToCreatedUsers.isEmpty()) {

						// Prepare list of permission set assignments to create
						List<PermissionSetAssignment> permissionSetAssignments = new List<PermissionSetAssignment>();

						// Collect all permission set names from the permission set assignment hard coded map
						Set<String> permissionSetNames = new Set<String>();
						for (String primarySecondary : PERM_SET_ASSIGNMENT.keySet()) {
							Map<String,List<String>> primarySecondaryEntry = PERM_SET_ASSIGNMENT.get(primarySecondary);
							for (String membershipCategory : primarySecondaryEntry.keySet()) {
								List<String> permissionSetList = primarySecondaryEntry.get(membershipCategory);
								permissionSetNames.addAll(permissionSetList);
							} // end loop through membership categories
						} // end loop through primary / secondary entries

						System.debug('permission sets ' + permissionSetNames);

						// Create a map of the permission set name to its Id
						Map<String,Id> permSetNameToIdMap = new Map<String,Id>();
						for (PermissionSet permSet : [SELECT Id,Name FROM PermissionSet WHERE Name IN :permissionSetNames]) {
							permSetNameToIdMap.put(permSet.Name, permSet.Id);
						} // end loop through permission set names

						System.debug('permission set map ' + permSetNameToIdMap);

						// Go through successfully created users and look up their permission sets
						for (Id contactId : contactIdToCreatedUsers.keySet()) {
							User createdUser = contactIdToCreatedUsers.get(contactId);

							// We need fields on the original contact
							Contact originalContact = newContactsMap.get(contactId);

							// We need fields on the associated opportunity
							Opportunity opportunity = accountIdToOpportunity.get(originalContact.AccountId);

							// Get the data to lookup in the PERM_Set_ASSIGNMENT data structure
							String membershipCategory = opportunity.Account.Membership_Category__c;
							String primaryContact = originalContact.Primary_Contact__c;
							List<String> permissionSets = PERM_SET_ASSIGNMENT.get(primaryContact).get(membershipCategory);

							// Go through the permission set list
							for (String permissionSet : permissionSets) {

								// Convert to permission set id from the name via our map
								Id permissionSetId = permSetNameToIdMap.get(permissionSet);

								// Create new permission set assignment entry
								permissionSetAssignments.add(new PermissionSetAssignment(AssigneeId = createdUser.Id, PermissionSetId = permissionSetId));
							} // end loop through permission sets
						} // end loop through created users

						// if we have any permission set assignments then create them
						if (!permissionSetAssignments.isEmpty()) {
							List<Database.SaveResult> permSetResults = Database.insert(permissionSetAssignments,false);
							System.debug('perm set results ' + permSetResults);
						} // end check we have perm set assignments if
					} // end successful create check if
				} // end check for records to insert if
				else {
					System.debug('No users to create');
				} // end check for records to insert else
			} // end check for matching opportunities
		} // end check for primary contacts if
	} // end onAfterInsert
} // end class