/**
 * Created by szlat@softserveinc.com on 05/05/2022.
 * @description Optional plugin that sends logs via email.
 */
public without sharing class EmailLoggerPlugin implements LoggerPlugin.Triggerable {
    // Constants from LoggerParameter__mdt custom metadata type
    private static final String EMAIL_QUEUE_NAME = LoggerParameter.getString('EmailLoggingQueue', null);
    private static final List<String> EMAIL_RECIPIENTS = getRecipients(EMAIL_QUEUE_NAME);
    private static final LoggingLevel LOGGING_LEVEL = Logger.getLoggingLevel(LoggerParameter.getString('EmailLoggingLevel', null));
    private static final Integer LOG_ENTRIES_COUNT = LoggerParameter.getInteger('EmailLoggingLogEntryCount', 1);

    // Values shared across transaction
    private static List<Log__c> logs;
    private static Boolean isFirstExecution = true;
    private static Boolean logsSent = false;

    @TestVisible
    private static Integer logsSentCounter = 0;

    /**
     * @description Handles log sending via emails. This method is automatically called by Nebula Logger's plugin framework.
     * @param  configuration The instance of `LoggerPlugin__mdt` configured for this specific plugin
     * @param  triggerContext The instance of `LoggerTriggerableContext`, provided by the logging system
     */
    public void execute(LoggerPlugin__mdt configuration, LoggerTriggerableContext triggerContext) {
        if (triggerContext.SObjectType != Schema.Log__c.SObjectType || LOGGING_LEVEL == null) {
            return;
        }

        logs = (List<Log__c>) triggerContext.triggerNew;
        if (triggerContext.triggerOperationType == TriggerOperation.AFTER_UPDATE || triggerContext.triggerOperationType == TriggerOperation.AFTER_INSERT) {
            processLogs();
        }
    }

    private static void processLogs() {
        //to avoid trigger recursion
        //update in line 62 causes trigger recursion
        if (isFirstExecution) {
            List<Log__c> filtered = filterNotSentLogs(logs);
            Set<Id> logIds = (new Map<Id, Log__c>(filtered)).keySet();
            // requery logs with their log entries
            List<Log__c> fullLogs = requeryLogs(logIds);
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            if (!EMAIL_RECIPIENTS.isEmpty()) {
                String orgWideEmailName = LoggerParameter.getString('EmailLoggingOrgWideAddress', '');
                Id orgWideEmailId = EmailLoggerUtils.getOrgWideEmailAddress(orgWideEmailName)?.Id;
                for (Log__c log : fullLogs) {
                    EmailNotificationDto notification = convertToEmail(log);
                    Messaging.SingleEmailMessage singleEmail = new Messaging.SingleEmailMessage();
                    singleEmail.setOrgWideEmailAddressId(orgWideEmailId);
                    singleEmail.setSubject(notification.subject);
                    singleEmail.setToAddresses(EMAIL_RECIPIENTS);
                    singleEmail.setPlainTextBody(notification.body);
                    singleEmail.setFileAttachments(new Messaging.EmailFileAttachment [] 
                                        {notification.attachment});
                    
                    emails.add(singleEmail);
                }
            }
            if (!emails.isEmpty()) {
                try {
                    Messaging.SendEmailResult [] results = Messaging.sendEmail(emails);
                    processResults(results);
                } catch(Exception ex) {
                    // preventing logger framework from not saving Log__c records
                }               
            }
            if (logsSent) { 
                flagLogsSent(fullLogs);
                isFirstExecution = false;
                update fullLogs;   
            }
        }   
    }

    private static EmailNotificationDto convertToEmail(Log__c log) {
        EmailNotificationDto notification = new EmailNotificationDto();
        String logName = log.Name;
        notification.subject = String.format(Label.EmailSubject, new String [] { logName });
        String startTime = String.valueOf(log.StartTime__c);
        String endTime = String.valueOf(log.EndTime__c);
        String loggedBy = (String.isNotBlank(log.LoggedByUsername__c)) ? log.LoggedByUsername__c : log.LoggedByUsernameLink__c;
        String orgType = log.OrganizationEnvironmentType__c;
        String orgName = log.OrganizationName__c;
        String orgId = log.OrganizationId__c;
        String instanceName = log.OrganizationInstanceName__c;
        String logUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/' + log.Id;
        notification.body = String.format(Label.EmailBody, new String[] {
                        logName,
                        startTime,
                        endTime,
                        orgName,
                        orgType,
                        orgId,
                        instanceName,
                        loggedBy,
                        logUrl
        });
        notification.attachment = convertToAttachment(log.LogEntries__r, logName);
        return notification;
    }

    private static Messaging.EmailFileAttachment convertToAttachment(List<LogEntry__c> logEntries, String fileName) {
        String fileBody = '';
        for (LogEntry__c entry : logEntries) {
            fileBody += 'Message : ' +  entry.Message__c + '\n';
            if (String.isNotBlank(entry.StackTrace__c)) {
                fileBody += 'Stack Trace : ' + entry.StackTrace__c + '\n';
            }
            if (String.isNotBlank(entry.ExceptionStackTrace__c)) {
                fileBody += 'Exception Stack Trace : ' + entry.ExceptionStackTrace__c + '\n';
            }
            fileBody += '====================================================================== \n';
        }
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(fileName + '.txt');
        attachment.setBody(Blob.valueOf(fileBody));
        attachment.setContentType('text/plain');
        attachment.setInline(false);
        return attachment;
    }

    private static List<Log__c> filterNotSentLogs(Log__c [] logs) {
        List<Log__c> filtered = new List<Log__c>();
        for (Log__c log : logs) {
            if (!log.EmailLogSent__c) {
                filtered.add(log);
            }
        }
        return filtered;
    }

    private static List<Log__c> requeryLogs(Set<Id> logIds) {
        return [SELECT
            Id,
            Name,
            ApiVersion__c,
            EmailLogSent__c,
            EmailLogSentTimestamp__c,
            LoggedByUsername__c,
            LoggedByUsernameLink__c,
            OwnerId,
            TYPEOF Owner
                WHEN User THEN Username
                ELSE Name
            END,
            MaxLogEntryLoggingLevelOrdinal__c,
            OrganizationId__c,
            OrganizationEnvironmentType__c,
            OrganizationInstanceName__c,
            OrganizationName__c,
            Priority__c,
            StartTime__c,
            EndTime__c,
            TimeZoneId__c,
            TotalLogEntries__c,
            TotalERRORLogEntries__c,
            TotalWARNLogEntries__c,
            TransactionId__c,
            (
                SELECT Id, LoggingLevel__c, Message__c, 
                    StackTrace__c, ExceptionStackTrace__c
                FROM LogEntries__r
                WHERE LoggingLevelOrdinal__c >= :LOGGING_LEVEL.ordinal()
                ORDER BY Timestamp__c DESC
                LIMIT :LOG_ENTRIES_COUNT
            )
        FROM Log__c
        WHERE
        (Id IN :logIds OR EmailLogSent__c = FALSE)
        AND MaxLogEntryLoggingLevelOrdinal__c >= :LOGGING_LEVEL.ordinal()];
    }

    private static List<String> getRecipients(String queueName) {
        List<String> recipients = new List<String>();
        Group [] loggingQueues = [SELECT Email, (SELECT UserOrGroupId FROM GroupMembers) FROM Group WHERE DeveloperName = :queueName AND Type = 'Queue' LIMIT 1];
        Group loggingQueue = (loggingQueues.isEmpty()) ? null : loggingQueues[0];
        if (loggingQueue != null) {
            for (GroupMember gm : loggingQueue.GroupMembers) {
                if (gm.UserOrGroupId.getSobjectType() == User.SObjectType) {
                    recipients.add(String.valueOf(gm.UserOrGroupId));
                }
            }

            if (String.isNotBlank(loggingQueue.Email)) {
                recipients.add(loggingQueue.Email);
            }
        }
        
        return recipients;
    }

    private static void flagLogsSent(List<Log__c> logs) {
        for (Log__c log : logs) {
            log.EmailLogSent__c = true;
            log.EmailLogSentTimestamp__c = Datetime.now();
        }
    }

    private static void processResults(Messaging.SendEmailResult [] results) {
        for (Messaging.SendEmailResult result : results) {
            if (result.isSuccess()) {
                logsSentCounter++;
            }
        }
        logsSent = logsSentCounter > 0;
    }

    private class EmailNotificationDto {
        public String subject;
        public String body;
        public Messaging.EmailFileAttachment attachment;
    }
}