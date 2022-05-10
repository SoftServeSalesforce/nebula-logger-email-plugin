@IsTest
public class EmailLoggerPluginTest {

    @TestSetup
    private static void setup() {
        User admin = EmailLoggerTestUtils.createAdminUser(true);
        EmailLoggerTestUtils.mockGroupMember(admin);
    }

    @IsTest
    private static void testProcessLogs_Sucess() {
        EmailLoggerTestUtils.mockConfigurations();
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

        System.assertEquals(2, EmailLoggerPlugin.logsSentCounter);        
    }

    @IsTest
    private static void testProcessLogs_LoggingLevelBelowError() {
        EmailLoggerTestUtils.mockConfigurations();
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

        System.assertEquals(0, EmailLoggerPlugin.logsSentCounter);
    }
}