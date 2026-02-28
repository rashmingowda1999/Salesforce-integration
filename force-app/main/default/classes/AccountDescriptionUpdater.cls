public class AccountDescriptionUpdater {

    public static void updateAccountDescription(Id accountId, String newDescription) {
        // Retrieve the Account record1
        Account acc = [SELECT Id, Description FROM Account WHERE Id = :accountId];

        // Update the Description field111
        acc.Description = newDescription;

        // Update the record in the databasee
        update acc;
    }
}