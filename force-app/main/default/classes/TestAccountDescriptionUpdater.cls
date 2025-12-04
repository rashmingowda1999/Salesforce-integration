@isTest
private class TestAccountDescriptionUpdater {

    @isTest
    static void testUpdateAccountDescription() {
        // 1. Create Test Data
        // Create an Account record to test with
        Account testAccount = new Account(Name = 'Test Account', Description = 'Original Description');
        insert testAccount;

        // 2. Call the Method to Test
        // Call the method from the main class
        String updatedDescription = 'New Updated Description';
        AccountDescriptionUpdater.updateAccountDescription(testAccount.Id, updatedDescription);

        // 3. Verify Results11
        // Retrieve the updated Account record
        Account updatedAcc = [SELECT Id, Description FROM Account WHERE Id = :testAccount.Id];

        // Assert that the Description was updated correctly
        System.assertEquals(updatedDescription, updatedAcc.Description, 'Account description should be updated.');
    }
}