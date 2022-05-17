@IsTest
public class EmailLoggerPluginTest {
    private static final String LOG_RECIPIENTS_GROUP_NAME = 'TestLogRecipients';
    private static final String ORG_WIDE_EMAIL_ADDRESS_NAME = 'Logger';
    private static final Integer FAILED_LOGS_RESEND_POLICY = 2;
    private static final Integer LIMIT_LOG_ENTRY_COUNT = 5;

    @TestSetup
    private static void setup() {
        User admin = EmailLoggerTestUtils.createAdminUser(true);
        EmailLoggerTestUtils.mockGroupMember(admin, LOG_RECIPIENTS_GROUP_NAME);
    }

    @IsTest
    private static void testProcessLogs_Sucess() {
        EmailLoggerTestUtils.mockPluginConfigurations(LOG_RECIPIENTS_GROUP_NAME, LoggingLevel.ERROR,
                                                ORG_WIDE_EMAIL_ADDRESS_NAME, LIMIT_LOG_ENTRY_COUNT, 
                                                FAILED_LOGS_RESEND_POLICY);

        Log__c log1 = EmailLoggerTestUtils.createLog(false);
        Log__c log2 = EmailLoggerTestUtils.createLog(false);
        LogEntry__c [] logEntries = new List<LogEntry__c>();

        Test.startTest();
            insert new Log__c [] {log1, log2};
            LogEntry__c [] log1Entries = EmailLoggerTestUtils.createLogEntries(log1, 2, LoggingLevel.ERROR, false);
            LogEntry__c [] log2Entries = EmailLoggerTestUtils.createLogEntries(log2, 2, LoggingLevel.ERROR, false);
            logEntries.addAll(log1Entries);
            logEntries.addAll(log2Entries);
            insert logEntries;
        Test.stopTest();

        Log__c [] sentLogs = [SELECT Id, EmailLogFailedTimestamp__c, EmailLogSentTimestamp__c FROM Log__c WHERE EmailLogSent__c = TRUE];
        System.assertEquals(2, EmailLoggerPlugin.logsSentCounter, 'There is a mismatch in number of sent email logs');
        System.assertEquals(2, sentLogs.size(), 'There is a mismatch in number of sent email logs');

        System.assertNotEquals(null, sentLogs[0].EmailLogSentTimestamp__c, 'This log should have EmailLogSentTimestamp__c populated');
        System.assertEquals(null, sentLogs[0].EmailLogFailedTimestamp__c, 'This log should not have EmailLogSentTimestamp__c populated');

        System.assertNotEquals(null, sentLogs[1].EmailLogSentTimestamp__c, 'This log should have EmailLogSentTimestamp__c populated');
        System.assertEquals(null, sentLogs[1].EmailLogFailedTimestamp__c, 'This log should not have EmailLogSentTimestamp__c populated');    
    }

    @IsTest
    private static void testProcessLogs_LoggingLevelBelowError() {
        EmailLoggerTestUtils.mockPluginConfigurations(LOG_RECIPIENTS_GROUP_NAME, LoggingLevel.ERROR,
                                                ORG_WIDE_EMAIL_ADDRESS_NAME, LIMIT_LOG_ENTRY_COUNT, 
                                                FAILED_LOGS_RESEND_POLICY);

        Log__c log1 = EmailLoggerTestUtils.createLog(false);
        Log__c log2 = EmailLoggerTestUtils.createLog(false);
        LogEntry__c [] logEntries = new List<LogEntry__c>();

        Test.startTest();
            insert new Log__c [] {log1, log2};
            LogEntry__c [] log1Entries = EmailLoggerTestUtils.createLogEntries(log1, 2, LoggingLevel.DEBUG, false);
            LogEntry__c [] log2Entries = EmailLoggerTestUtils.createLogEntries(log2, 2, LoggingLevel.DEBUG, false);
            logEntries.addAll(log1Entries);
            logEntries.addAll(log2Entries);
            insert logEntries;
        Test.stopTest();

        Log__c [] sentLogs = [SELECT Id, EmailLogFailedTimestamp__c, EmailLogSentTimestamp__c FROM Log__c WHERE EmailLogSent__c = TRUE];
        System.assertEquals(0, EmailLoggerPlugin.logsSentCounter, 'There is a mismatch in number of sent email logs');
        System.assertEquals(0, EmailLoggerPlugin.logsSentCounter, 'There is a mismatch in number of sent email logs');
    }

    @IsTest
    private static void testProcessLogs_ResendPolicyTwoDays() {
        // pre-populate logs that failed to send previously and then enable plugin
        Log__c log1 = EmailLoggerTestUtils.createLog(false);
        Log__c log2 = EmailLoggerTestUtils.createLog(false);

        Datetime minFailedToSendDt = System.now().addDays(-1);
        Datetime maxFailedToSendDt = System.now().addDays(-4);

        log1.EmailLogFailedTimestamp__c = minFailedToSendDt;
        log2.EmailLogFailedTimestamp__c = maxFailedToSendDt;
        insert new Log__c [] {log1, log2};

        LogEntry__c [] logEntries = new List<LogEntry__c>();
        LogEntry__c [] log1Entries = EmailLoggerTestUtils.createLogEntries(log1, 1, LoggingLevel.ERROR, false);
        LogEntry__c [] log2Entries = EmailLoggerTestUtils.createLogEntries(log2, 2, LoggingLevel.ERROR, false);
        logEntries.addAll(log1Entries);
        logEntries.addAll(log2Entries);
        insert logEntries;

        // enable plugin
        EmailLoggerTestUtils.mockPluginConfigurations(LOG_RECIPIENTS_GROUP_NAME, LoggingLevel.ERROR,
                                                ORG_WIDE_EMAIL_ADDRESS_NAME, LIMIT_LOG_ENTRY_COUNT, 
                                                FAILED_LOGS_RESEND_POLICY);

        Log__c log3 = EmailLoggerTestUtils.createLog(false);
        insert log3;

        Test.startTest();
            LogEntry__c [] log3Entries = EmailLoggerTestUtils.createLogEntries(log3, 3, LoggingLevel.ERROR, false);
            insert log3Entries;
        Test.stopTest();

        Log__c [] notSentLogs = [SELECT Id, EmailLogFailedTimestamp__c, EmailLogSentTimestamp__c FROM Log__c WHERE EmailLogSent__c = FALSE];
        System.assertEquals(1, notSentLogs.size(), 'There is a mismatch in number of not sent logs');
        System.assertEquals(maxFailedToSendDt, notSentLogs[0].EmailLogFailedTimestamp__c, 'This log should have EmailLogFailedTimestamp__c populated');
        System.assertEquals(null, notSentLogs[0].EmailLogSentTimestamp__c, 'This log should not have EmailLogSentTimestamp__c populated');

        Log__c [] sentLogs = [SELECT Id, EmailLogFailedTimestamp__c, EmailLogSentTimestamp__c FROM Log__c WHERE EmailLogSent__c = TRUE];
        System.assertEquals(2, sentLogs.size(), 'There is a mismatch in number of sent logs');
        System.assertEquals(2, EmailLoggerPlugin.logsSentCounter, 'There is a mismatch in number of sent logs');

        System.assertNotEquals(null, sentLogs[0].EmailLogSentTimestamp__c, 'This log should have EmailLogSentTimestamp__c populated');
        System.assertEquals(null, sentLogs[0].EmailLogFailedTimestamp__c, 'This log should have EmailLogFailedTimestamp__c populated');

        System.assertNotEquals(null, sentLogs[1].EmailLogSentTimestamp__c, 'This log should not have EmailLogSentTimestamp__c populated');
        System.assertEquals(null, sentLogs[1].EmailLogFailedTimestamp__c, 'This log should not have EmailLogFailedTimestamp__c populated'); 
    }

    @IsTest
    private static void testProcessLogs_NoRecipientsGroup() {
        EmailLoggerTestUtils.mockPluginConfigurations('', LoggingLevel.ERROR,
                                                ORG_WIDE_EMAIL_ADDRESS_NAME, LIMIT_LOG_ENTRY_COUNT, 
                                                FAILED_LOGS_RESEND_POLICY);

        Log__c log1 = EmailLoggerTestUtils.createLog(false);
        Log__c log2 = EmailLoggerTestUtils.createLog(false);
        LogEntry__c [] logEntries = new List<LogEntry__c>();

        Test.startTest();
            insert new Log__c [] {log1, log2};
            LogEntry__c [] log1Entries = EmailLoggerTestUtils.createLogEntries(log1, 2, LoggingLevel.ERROR, false);
            LogEntry__c [] log2Entries = EmailLoggerTestUtils.createLogEntries(log2, 2, LoggingLevel.ERROR, false);
            logEntries.addAll(log1Entries);
            logEntries.addAll(log2Entries);
            insert logEntries;
        Test.stopTest();

        Log__c [] sentLogs = [SELECT Id, EmailLogFailedTimestamp__c, EmailLogSentTimestamp__c FROM Log__c WHERE EmailLogSent__c = TRUE];
        System.assertEquals(0, EmailLoggerPlugin.logsSentCounter, 'There is a mismatch in number of sent email logs');
        System.assertEquals(0, EmailLoggerPlugin.logsSentCounter, 'There is a mismatch in number of sent email logs');
    }
}