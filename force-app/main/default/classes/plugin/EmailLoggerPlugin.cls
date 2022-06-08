/**
 * Created by szlat@softserveinc.com on 05/05/2022.
 * @description Optional plugin that sends logs via email.
 */
public without sharing class EmailLoggerPlugin implements LoggerPlugin.Triggerable {
    // Constants from LoggerParameter__mdt custom metadata type
    private static final String LOG_RECIPIENTS_QUEUE_NAME = LoggerParameter.getString('EmailLogRecipientsQueueName', null);
    private static final List<String> LOG_RECIPIENTS = getRecipients(LOG_RECIPIENTS_QUEUE_NAME);
    private static final LoggingLevel MIN_LOGGING_LEVEL = Logger.getLoggingLevel(LoggerParameter.getString('MinEmailLoggingLevel', null));
    private static final Integer LIMIT_LOG_ENTRIES_COUNT = LoggerParameter.getInteger('LimitEmailLogEntryCount', 1);
    private static final Integer FAILED_LOGS_RESEND_POLICY = LoggerParameter.getInteger('FailedEmailLogResendPolicy', 0);

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
        if (triggerContext.SObjectType != Schema.Log__c.SObjectType || MIN_LOGGING_LEVEL == null) {
            return;
        }

        logs = (List<Log__c>) triggerContext.triggerNew;
        // handling after update only because we don't have enough info about logs
        // on after insert
        if (triggerContext.triggerOperationType == TriggerOperation.AFTER_UPDATE) {
            processLogs();
        }
    }

    private static void processLogs() {
        //to avoid trigger recursion
        //update in line 62 causes trigger recursion
        if (isFirstExecution) {
            List<Log__c> filteredLogs = filterNotSentLogs(logs);
            Set<Id> logIds = (new Map<Id, Log__c>(filteredLogs)).keySet();
            // requery logs with their log entries
            List<Log__c> fullLogs = requeryFullLogs(logIds);
            List<Messaging.SingleEmailMessage> emailLogs = new List<Messaging.SingleEmailMessage>();
            if (!LOG_RECIPIENTS.isEmpty()) {
                String defaultSenderName = LoggerParameter.getString('EmailLoggingOrgWideEmailAddressName', null);
                Id defaultSenderId = EmailLoggerUtils.getOrgWideEmailAddress(defaultSenderName)?.Id;
                for (Log__c log : fullLogs) {
                    EmailNotificationDto convertedLog = convertToEmail(log);
                    Messaging.SingleEmailMessage emailLog = new Messaging.SingleEmailMessage();
                    emailLog.setOrgWideEmailAddressId(defaultSenderId);
                    emailLog.setSubject(convertedLog.subject);
                    emailLog.setToAddresses(LOG_RECIPIENTS);
                    emailLog.setPlainTextBody(convertedLog.body);
                    emailLog.setFileAttachments(new Messaging.EmailFileAttachment [] 
                                        {convertedLog.attachment});
                    
                    emailLogs.add(emailLog);
                }
            }

            if (!emailLogs.isEmpty()) {
                try {
                    Messaging.SendEmailResult [] emailResults = Messaging.sendEmail(emailLogs);
                    processEmailResults(emailResults);
                } catch (Exception ex) {
                    System.debug(ex.getMessage());
                    // prevent logger framework from not saving logs
                } finally {
                    postProcessLogs(fullLogs);
                }
            }
        }
    }

    private static EmailNotificationDto convertToEmail(Log__c log) {
        EmailNotificationDto emailNotification = new EmailNotificationDto();
        String logName = log.Name;
        emailNotification.subject = String.format(Label.EmailSubject, new String [] { logName });
        String startTime = String.valueOf(log.StartTime__c);
        String endTime = String.valueOf(log.EndTime__c);
        String loggedBy = (String.isNotBlank(log.LoggedByUsername__c)) ? log.LoggedByUsername__c : log.LoggedByUsernameLink__c;
        String orgType = log.OrganizationEnvironmentType__c;
        String orgName = log.OrganizationName__c;
        String orgId = log.OrganizationId__c;
        String instanceName = log.OrganizationInstanceName__c;
        String logUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/' + log.Id;
        emailNotification.body = String.format(Label.EmailBody, new String [] {
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
        emailNotification.attachment = convertToAttachment(log.LogEntries__r, logName);
        return emailNotification;
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
        Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
        emailAttachment.setFileName(fileName + '.txt');
        emailAttachment.setBody(Blob.valueOf(fileBody));
        emailAttachment.setContentType('text/plain');
        emailAttachment.setInline(false);
        return emailAttachment;
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

    private static List<Log__c> requeryFullLogs(Set<Id> logIds) {
        Datetime failedToSendMinDT = System.now().addDays(-FAILED_LOGS_RESEND_POLICY);
        // requery new logs and old failed to send logs that have EmailLogFailedTimestamp__c >= failedToSendMinDT
        return [SELECT
            Id,
            Name,
            ApiVersion__c,
            EmailLogSent__c,
            EmailLogFailedTimestamp__c,
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
                WHERE LoggingLevelOrdinal__c >= :MIN_LOGGING_LEVEL.ordinal()
                ORDER BY Timestamp__c DESC
                LIMIT :LIMIT_LOG_ENTRIES_COUNT
            )
        FROM Log__c
        WHERE
        (MaxLogEntryLoggingLevelOrdinal__c >= :MIN_LOGGING_LEVEL.ordinal())
            AND (EmailLogFailedTimestamp__c >= :failedToSendMinDT OR Id IN :logIds)];
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

    private static void processEmailResults(Messaging.SendEmailResult [] results) {
        for (Messaging.SendEmailResult result : results) {
            if (result.isSuccess()) {
                logsSentCounter++;
            }
        }
        logsSent = logsSentCounter > 0;
    }

    private static void postProcessLogs(List<Log__c> logs) {
        if (logsSent) {
            markLogsAsSent(logs);
        } else {
            markLogsAsFailedToSend(logs);
        }
        isFirstExecution = false;
        update logs;
    }

    private static void markLogsAsSent(List<Log__c> logs) {
        for (Log__c log : logs) {
            log.EmailLogSent__c = true;
            log.EmailLogSentTimestamp__c = System.now();
            if (log.EmailLogFailedTimestamp__c != null) {
                log.EmailLogFailedTimestamp__c = null;
            }
        }
    }

    private static void markLogsAsFailedToSend(List<Log__c> logs) {
        for (Log__c log : logs) {
            log.EmailLogSent__c = false;
            log.EmailLogFailedTimestamp__c = System.now();
            if (log.EmailLogSentTimestamp__c != null) {
                log.EmailLogSentTimestamp__c = null;
            }
        }
    }

    private class EmailNotificationDto {
        public String subject;
        public String body;
        public Messaging.EmailFileAttachment attachment;
    }
}