trigger AllContactTrigger on Contact (after insert, before update, after update){
    
    //This if loop belongs to the BCI Mindflash and it is used to trigger the MindflashAPI Class
    if(Trigger.isBefore && Trigger.isUpdate){
        System.debug('Before: ' + Trigger.old[0].MindflashUserId__c);
        System.debug('After: ' + Trigger.new[0].MindflashUserId__c);
        
        for(Integer i = 0; i < Trigger.new.size(); i++){
            if (Trigger.new[i].CreateMindflashTrainee__c){
                if(String.isBlank(Trigger.old[i].MindflashUserId__c) && String.isBlank(Trigger.new[i].MindflashUserId__c)) {
                    Trigger.new[i].MindflashUserId__c = 'Updating';

                    // SJ (PT) 18 Sept 2024 -added in the training BCP Account that we know has already been populated during registration
                    System.debug('triggered contact ' + Trigger.new[i].TrainingContactBCPAccount__c);
                    System.enqueueJob(new MindflashApi.MindflashAsyncCaller(Trigger.new[i].Id, Trigger.new[i].TrainingContactBCPAccount__c));
                }
            }
        }
    }
  //If any DML operation happens in the future then it shouldn't fire the trigger again
    if(!(System.isFuture()||System.isBatch()))
 {
     // Avoid the trigger from firing thrice by setting a boolean value to false if record is triggered once
     if(!TriggerManager.accountTrigger.afterInsert){
    //Making a call to the handler class
         AllContactTriggerHandler  handler = new AllContactTriggerHandler();
        handler.chainpointApi(Trigger.new);
    }
    }

    // PT (SJ) - 9 Oct 2024 - Add logic automatically creating users TORs#1508
    if (Trigger.isAfter && Trigger.isInsert) {
        AllContactTriggerHandler.onAfterInsert(Trigger.newMap);
    } // end after insert check
 }