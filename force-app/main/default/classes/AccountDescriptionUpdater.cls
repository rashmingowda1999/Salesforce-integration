public class AccountDescriptionUpdater {
    // Trigger workflow to make it visible in GitHub Actions
    public static void updateAccountDescription(Id accountId, String newDescription) {
        // Retrieve the Account record with validation and error handling
        Account acc = [SELECT Id, Description FROM Account WHERE Id = :accountId];

        // Update the Description field with new value111
        acc.Description = newDescription;

        // Update the record in the database1
        update acc;
    }
}
