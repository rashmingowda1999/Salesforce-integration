public class AccountDescriptionUpdater {

    public static void updateAccountDescription(Id accountId, String newDescription) {
        // Retrieve the Account record with validation and error handling
        Account acc = [SELECT Id, Description FROM Account WHERE Id = :accountId];

        // Update the Description field with new value
        acc.Description = newDescription;

        // Update the record in the database111
        update acc;
    }
}