@IsTest
public class EmailLoggerPluginTest {

    @TestSetup
    private static void setup() {
        User admin = TestUtils.createAdminUser(true);
        TestUtils.mockGroupMember(admin);
    }

    @IsTest
    private static void testProcessLogs_Sucess() {
        TestUtils.mockConfigurations();
        Log__c log1 = TestUtils.createLog(false);
        Log__c log2 = TestUtils.createLog(false);
        LogEntry__c [] logEntries = new List<LogEntry__c>();

        Test.startTest();
            insert new Log__c [] {log1, log2};
            LogEntry__c [] log1Entries = TestUtils.createLogEntries(log1, 2, LoggingLevel.ERROR, false);
            LogEntry__c [] log2Entries = TestUtils.createLogEntries(log2, 2, LoggingLevel.ERROR, false);
            logEntries.addAll(log1Entries);
            logEntries.addAll(log2Entries);
            insert logEntries;
        Test.stopTest();

        System.assertEquals(2, EmailLoggerPlugin.logsSentCounter);        
    }

    @IsTest
    private static void testProcessLogs_LoggingLevelBelowError() {
        TestUtils.mockConfigurations();
        Log__c testLog1 = TestUtils.createLog(false);
        Log__c testLog2 = TestUtils.createLog(false);
        LogEntry__c [] logEntries = new List<LogEntry__c>();

        Test.startTest();
            insert new Log__c [] {log1, log2};
            LogEntry__c [] log1Entries = TestUtils.createLogEntries(log1, 2, LoggingLevel.DEBUG, false);
            LogEntry__c [] log2Entries = TestUtils.createLogEntries(log2, 2, LoggingLevel.DEBUG, false);
            logEntries.addAll(log1Entries);
            logEntries.addAll(log2Entries);
            insert logEntries;
        Test.stopTest();

        System.assertEquals(0, EmailLoggerPlugin.logsSentCounter);
    }
}