/**
 * Created by szlat@softserveinc.com on 05/08/2022.
 * @description Utils class for tests.
 */
@IsTest
public class EmailLoggerTestUtils {
    public static final String EMAIL_LOGGING_QUEUE_NAME = 'TestGroup';
    public static final LoggingLevel EMAIL_LOGGING_LEVEL = LoggingLevel.ERROR;
    public static final String ORG_WIDE_EMAIL_NAME = 'Logger Test';
    public static final Integer LOG_ENTRY_COUNT = 5;
   
    public static Log__c createLog(Boolean toInsert) {
        Log__c log = new Log__c(
            LoggedBy__c = UserInfo.getUserId(),
            EmailLogSent__c = false
        );

        if (toInsert) {
            insert log;
        }
        return log;
    }

    public static List<LogEntry__c> createLogEntries(Log__c log, Integer logEntryNumber, LoggingLevel logLvl, Boolean toInsert) {
        List<LogEntry__c> logEntries = new List<LogEntry__c>();
        for (Integer i = 1; i <= logEntryNumber; i++) {
            logEntries.add(new LogEntry__c(
                Log__c = log.Id,
                StackTrace__c = 'Some stack trace...',
                LoggingLevel__c = logLvl.name(),
                LoggingLevelOrdinal__c = logLvl.ordinal(),
                Timestamp__c = System.now()
            ));
        }

        if (toInsert) {
            insert logEntries;
        }
        return logEntries;
    }

    public static void mockConfigurations() {
        LoggerTestConfigurator.setMock(
            new LoggerPlugin__mdt(DeveloperName = 'EmailLoggerPlugin', IsEnabled__c = true, SObjectHandlerApexClass__c = EmailLoggerPlugin.class.getName())
        );
        LoggerTestConfigurator.setMock(new LoggerParameter__mdt(DeveloperName = 'EmailLoggingQueue', Value__c = EMAIL_LOGGING_QUEUE_NAME));
        LoggerTestConfigurator.setMock(new LoggerParameter__mdt(DeveloperName = 'EmailLoggingLevel', Value__c = EMAIL_LOGGING_LEVEL.name()));
        LoggerTestConfigurator.setMock(new LoggerParameter__mdt(DeveloperName = 'EmailLoggingOrgWideAddress', Value__c = ORG_WIDE_EMAIL_NAME));
        LoggerTestConfigurator.setMock(new LoggerParameter__mdt(DeveloperName = 'EmailLoggingLogEntryCount', Value__c = String.valueOf(LOG_ENTRY_COUNT)));
    }

    public static User createAdminUser(Boolean toInsert) {
        Integer randomNum = Integer.valueOf(Math.random() * 1000000);
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User admin = new User(
            Alias = ('test' + randomNum).right(8),
            Email='newuser@testorg.com' + randomNum,
            EmailEncodingKey='UTF-8',
            LastName='Testing',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='newuser@testorg.com' + randomNum  
        );

        if (toInsert) {
            insert admin;
        }
        return admin;
    }

    public static void mockGroupMember(User groupMember) {
        Group mockGroup = new Group(
            Name = EMAIL_LOGGING_QUEUE_NAME,
            DeveloperName = EMAIL_LOGGING_QUEUE_NAME,
            Type = 'Queue'
        );
        insert mockGroup;
        GroupMember mockMember = new GroupMember(
            GroupId = mockGroup.Id,
            UserOrGroupId = groupMember.Id
        );
        insert mockMember;
    }
}
