@isTest
private class ContactEmailUpdaterTest {

    /**
     * Test data setup - creates test contacts11
     */
    @testSetup
    static void setupTestData() {
        List<Contact> testContacts = new List<Contact>();

        testContacts.add(new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@original.com'
        ));

        testContacts.add(new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@original.com'
        ));

        testContacts.add(new Contact(
            FirstName = 'Bob',
            LastName = 'Johnson',
            Email = 'bob.johnson@original.com'
        ));

        insert testContacts;
    }

    /**
     * Test successful email update for a single contact
     */
    @isTest
    static void testUpdateContactEmail_Success() {
        // Get a test contact
        Contact testContact = [SELECT Id, Email FROM Contact WHERE FirstName = 'John' LIMIT 1];
        String newEmail = 'john.doe.updated@newdomain.com';

        Test.startTest();
        ContactEmailUpdater.updateContactEmail(testContact.Id, newEmail);
        Test.stopTest();

        // Verify the email was updated
        Contact updatedContact = [SELECT Id, Email FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals(newEmail, updatedContact.Email, 'Email should be updated to new value');
    }

    /**
     * Test exception when contact ID is null
     */
    @isTest
    static void testUpdateContactEmail_NullContactId() {
        String newEmail = 'test@example.com';

        Test.startTest();
        try {
            ContactEmailUpdater.updateContactEmail(null, newEmail);
            System.assert(false, 'Expected IllegalArgumentException for null contact ID');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Contact ID cannot be null'),
                         'Should throw exception for null contact ID: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test exception when email is blank
     */
    @isTest
    static void testUpdateContactEmail_BlankEmail() {
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        Test.startTest();
        try {
            ContactEmailUpdater.updateContactEmail(testContact.Id, '');
            System.assert(false, 'Expected IllegalArgumentException for blank email');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Email address cannot be blank'),
                         'Should throw exception for blank email: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test exception when email format is invalid
     */
    @isTest
    static void testUpdateContactEmail_InvalidEmailFormat() {
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        String invalidEmail = 'invalid-email-format';

        Test.startTest();
        try {
            ContactEmailUpdater.updateContactEmail(testContact.Id, invalidEmail);
            System.assert(false, 'Expected IllegalArgumentException for invalid email format');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Invalid email format'),
                         'Should throw exception for invalid email format: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test QueryException when contact doesn't exist
     */
    @isTest
    static void testUpdateContactEmail_NonexistentContact() {
        // Create and delete a contact to get a valid but non-existent ID
        Contact tempContact = new Contact(FirstName = 'Temp', LastName = 'Contact', Email = 'temp@test.com');
        insert tempContact;
        Id nonexistentId = tempContact.Id;
        delete tempContact;

        Test.startTest();
        try {
            ContactEmailUpdater.updateContactEmail(nonexistentId, 'test@example.com');
            System.assert(false, 'Expected QueryException for nonexistent contact');
        } catch (QueryException e) {
            System.assert(e.getMessage().contains('List has no rows'),
                         'Should throw QueryException for nonexistent contact: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test successful bulk email update for multiple contacts
     */
    @isTest
    static void testUpdateContactEmailsBulk_Success() {
        List<Contact> testContacts = [SELECT Id, Email FROM Contact ORDER BY FirstName];
        Map<Id, String> emailUpdateMap = new Map<Id, String>();

        emailUpdateMap.put(testContacts[1].Id, 'jane.updated@newdomain.com'); // Jane
        emailUpdateMap.put(testContacts[2].Id, 'john.updated@newdomain.com'); // John

        Test.startTest();
        ContactEmailUpdater.updateContactEmailsBulk(emailUpdateMap);
        Test.stopTest();

        // Verify emails were updated
        testContacts = [SELECT Id, Email, FirstName FROM Contact WHERE Id IN :emailUpdateMap.keySet() ORDER BY FirstName];

        System.assertEquals('jane.updated@newdomain.com', testContacts[0].Email,
                           'Jane\'s email should be updated');
        System.assertEquals('john.updated@newdomain.com', testContacts[1].Email,
                           'John\'s email should be updated');
    }

    /**
     * Test bulk update with null/empty map
     */
    @isTest
    static void testUpdateContactEmailsBulk_NullMap() {
        Test.startTest();
        // Should not throw any exception
        ContactEmailUpdater.updateContactEmailsBulk(null);
        ContactEmailUpdater.updateContactEmailsBulk(new Map<Id, String>());
        Test.stopTest();

        // Test passes if no exceptions are thrown
        System.assert(true, 'No exceptions should be thrown for null/empty maps');
    }

    /**
     * Test bulk update with blank emails (should skip those entries)
     */
    @isTest
    static void testUpdateContactEmailsBulk_BlankEmails() {
        List<Contact> testContacts = [SELECT Id, Email FROM Contact LIMIT 2];
        String originalEmail = testContacts[0].Email;

        Map<Id, String> emailUpdateMap = new Map<Id, String>();
        emailUpdateMap.put(testContacts[0].Id, ''); // Blank email - should be skipped
        emailUpdateMap.put(testContacts[1].Id, 'valid@email.com'); // Valid email

        Test.startTest();
        ContactEmailUpdater.updateContactEmailsBulk(emailUpdateMap);
        Test.stopTest();

        // Verify results
        testContacts = [SELECT Id, Email FROM Contact WHERE Id IN :emailUpdateMap.keySet() ORDER BY Email];

        // First contact should keep original email (blank was skipped)
        // Second contact should have new email
        Boolean originalEmailFound = false;
        Boolean newEmailFound = false;

        for (Contact c : testContacts) {
            if (c.Email == originalEmail) {
                originalEmailFound = true;
            }
            if (c.Email == 'valid@email.com') {
                newEmailFound = true;
            }
        }

        System.assert(originalEmailFound, 'Original email should be preserved when blank email provided');
        System.assert(newEmailFound, 'Valid email should be updated');
    }
}