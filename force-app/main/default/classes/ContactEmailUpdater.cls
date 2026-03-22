public class ContactEmailUpdater {

    /**
     * Updates a contact's email address
     * @param contactId The ID of the contact to update
     * @param newEmail The new email address
     */
    public static void updateContactEmail(Id contactId, String newEmail) {
        // Validate input parameters
        if (contactId == null) {
            throw new IllegalArgumentException('Contact ID cannot be null');
        }

        if (String.isBlank(newEmail)) {
            throw new IllegalArgumentException('Email address cannot be blank');
        }

        // Validate email format (basic validation)
        if (!newEmail.contains('@') || !newEmail.contains('.')) {
            throw new IllegalArgumentException('Invalid email format');
        }

        // Retrieve the Contact record
        Contact contact = [SELECT Id, Email FROM Contact WHERE Id = :contactId];

        // Update the Email field
        contact.Email = newEmail;

        // Update the record in the database
        update contact;
    }

    /**
     * Bulk update multiple contacts' email addresses
     * @param contactEmailMap Map of Contact ID to new email address
     */
    public static void updateContactEmailsBulk(Map<Id, String> contactEmailMap) {
        if (contactEmailMap == null || contactEmailMap.isEmpty()) {
            return;
        }

        // Retrieve all contacts
        List<Contact> contactsToUpdate = [SELECT Id, Email FROM Contact WHERE Id IN :contactEmailMap.keySet()];

        // Update email addresses
        for (Contact contact : contactsToUpdate) {
            String newEmail = contactEmailMap.get(contact.Id);
            if (String.isNotBlank(newEmail)) {
                contact.Email = newEmail;
            }
        }

        // Bulk update
        update contactsToUpdate;
    }
}