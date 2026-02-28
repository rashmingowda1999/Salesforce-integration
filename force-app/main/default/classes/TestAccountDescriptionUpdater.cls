@isTest
private class TestAccountDescriptionUpdater {

    /**
     * Common test data created once for all methods in this class.
     */
    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account', Description = 'Original Description');
        insert acc;
    }

    @isTest
    static void testUpdateAccountDescription() {
        Account acc = [SELECT Id, Description FROM Account LIMIT 1];
        String newDesc = 'New Updated Description';

        Test.startTest();
        AccountDescriptionUpdater.updateAccountDescription(acc.Id, newDesc);
        Test.stopTest();

        acc = [SELECT Id, Description FROM Account WHERE Id = :acc.Id];
        System.assertEquals(newDesc, acc.Description, 'Description should be updated');
    }

    @isTest
    static void testUpdateNonexistentAccount() {
        Id bogusId = Id.valueOf('001000000000000AAD');

        Test.startTest();
        try {
            AccountDescriptionUpdater.updateAccountDescription(bogusId, 'irrelevant');
            System.assert(false, 'Expected exception due to missing Account');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('List has no rows'), 'Unexpected error: ' + e.getMessage());
        }
        Test.stopTest();
    }
}

