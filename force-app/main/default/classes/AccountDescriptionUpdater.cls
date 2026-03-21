public class AccountDescriptionUpdater {

    public static void updateAccountDescription(Id accountId, String newDescription) {
        // Retrieve the Account record111
        Account acc = [SELECT Id, Description FROM Account WHERE Id = :accountId];

        // Update the Description field
        acc.Description = newDescription;

        // Update the record in the database
        update acc;
    }
}