@isTest
private class TestAccountDescriptionUpdater {

    /**
     * Test data setup for AccountDescriptionUpdater test class1.
     * Creates a test account with initial description.
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
        // use a valid Id that doesn't exist by creating then deleting a record
        Account exp = [SELECT Id FROM Account LIMIT 1];
        delete exp;
        Id bogusId = exp.Id;

        Test.startTest();
        try {
            AccountDescriptionUpdater.updateAccountDescription(bogusId, 'irrelevant');
            System.assert(false, 'Expected exception due to missing Account');
        } catch (QueryException e) {
            System.assert(e.getMessage().contains('List has no rows'), 'Unexpected error: ' + e.getMessage());
        }
        Test.stopTest();
    }
}

