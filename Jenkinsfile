#!groovy
import groovy.json.JsonSlurperClassic
node {

    def BUILD_NUMBER=env.BUILD_NUMBER
    def RUN_ARTIFACT_DIR="tests/${BUILD_NUMBER}"
    def SFDC_USERNAME

    def ORG_USERNAME=env.HUB_ORG_DH
    def SFDC_HOST = 'https://login.salesforce.com'
    
    def JWT_KEY_CRED_ID = 'sfdx'
    def JWT_KEY_LOCATION = '/var/lib/jenkins/certificates/server.key'
    def CONNECTED_APP_CONSUMER_KEY=env.CONNECTED_APP_CONSUMER_KEY_DH
    def toolbelt = tool 'toolbelt'
    def NEBULA_LOGGER_PACKAGE_ID ='04t5Y0000015lgBQAQ'

    // Default dev hub values
    withCredentials([
            string(credentialsId: 'LOGGER_DEV_USER', variable: 'USER'),
            string(credentialsId: 'LOGGER_DEV_KEY', variable: 'KEY'),
            ]) {
            ORG_USERNAME = USER
            CONNECTED_APP_CONSUMER_KEY = KEY
    }

    stage('checkout source') {
        // when running in multi-branch job, one must issue this command
        checkout scm
    }

    boolean isDevHub = env.BRANCH_NAME.equalsIgnoreCase('main')

    withCredentials([file(credentialsId: JWT_KEY_CRED_ID, variable: 'jwt_key_file')]) {
        
        if (!isDevHub) {
            stage('Create Scratch Org') {

                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${ORG_USERNAME} --jwtkeyfile ${JWT_KEY_LOCATION} --instanceurl ${SFDC_HOST}"
                if (rc != 0) { error 'hub org authorization failed' }
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:config:set defaultdevhubusername=${ORG_USERNAME}"
                // need to pull out assigned username
                rmsg = sh returnStdout: true, script: "${toolbelt}/sfdx force:org:create --definitionfile config/project-scratch-def.json -d 1 --json --setdefaultusername"
                printf rmsg
                def jsonSlurper = new JsonSlurperClassic()
                def robj = jsonSlurper.parseText(rmsg)
                if (robj.status != 0) { error 'org creation failed: ' + robj.message }
                SFDC_USERNAME=robj.result.username
                robj = null
            }

            stage('Install Dependent Packages') {
                env.SFDX_DISABLE_SOURCE_MEMBER_POLLING = true
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:package:install --package ${NEBULA_LOGGER_PACKAGE_ID} --noprompt --targetusername ${SFDC_USERNAME} --wait 5"
                if (rc != 0) {
                    deleteScratchOrg(toolbelt, SFDC_USERNAME)
                    error 'Install Nebula Logger failed'
                }
            }

            stage('Push To Scratch Org') {
                env.SFDX_DISABLE_SOURCE_MEMBER_POLLING = true
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:source:push --targetusername ${SFDC_USERNAME}"
                if (rc != 0) {
                    deleteScratchOrg(toolbelt, SFDC_USERNAME) 
                    error 'push failed'
                }
            }
        } else {
            stage('Install Dependent Packages') {
                env.SFDX_DISABLE_SOURCE_MEMBER_POLLING = true
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:package:install --package ${NEBULA_LOGGER_PACKAGE_ID} --noprompt --targetusername ${SFDC_USERNAME} --wait 5"
                if (rc != 0) {
                    deleteScratchOrg(toolbelt, SFDC_USERNAME)
                    error 'Install Nebula Logger failed'
                }
            }

            stage('Deploy To Org') {
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${ORG_USERNAME} --jwtkeyfile ${JWT_KEY_LOCATION} --setdefaultdevhubusername --instanceurl ${SFDC_HOST}"
                if (rc != 0) { error 'hub org authorization failed' }
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:source:deploy --targetusername ${ORG_USERNAME} -p \"force-app\""
                if (rc != 0) {
                    error 'Deploy failed'
                }
            }
        }
        stage('Run Apex Test') {
                sh "mkdir -p ${RUN_ARTIFACT_DIR}"
                timeout(time: 1000, unit: 'SECONDS') {
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:apex:test:run --testlevel RunLocalTests --wait 10 --outputdir ${RUN_ARTIFACT_DIR} --resultformat tap --targetusername ${isDevHub ? ORG_USERNAME : SFDC_USERNAME}"
                if (rc != 0) {
                    error 'apex test run failed'
                    if (!isDevHub) {
                        deleteScratchOrg(toolbelt, SFDC_USERNAME) 
                    }            
                }
            }
            if (!isDevHub) {
                stage('Delete Test Org') {
                    deleteScratchOrg(toolbelt, SFDC_USERNAME) 
                }
            }
        }

        stage('PMD Code Analysis') {
            rc = sh returnStatus: true, script: "sudo bash ./pmd/bin/run.sh pmd -d ./force-app/ -f xml -R ./ruleset.xml > pmd_result.xml"
            
            def pmd = scanForIssues tool: pmdParser(pattern: '**pmd_result.xml')
            publishIssues issues: [pmd]
        }

        stage('collect results') {
            junit keepLongStdio: true, testResults: 'tests/**/*-junit.xml'
        }
        stage('Archive Artifacts') {
            archiveArtifacts artifacts: 'pmd_result.xml', onlyIfSuccessful: false
        }
    }
}

boolean stringCredentialsExist(String id) {
    try {
        withCredentials([string(credentialsId: id, variable: 'irrelevant')]) {
            true
        }
    } catch (_) {
        false
    }
}

void deleteScratchOrg(toolbelt, userName) {
    timeout(time: 120, unit: 'SECONDS') {
        rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:org:delete --targetusername ${userName} --noprompt"
        if (rc != 0) {
            error 'org deletion request failed'
        }
    }
}