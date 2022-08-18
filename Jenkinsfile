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
    def PACKAGE_VERSION

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

        stage('Authorize DevHub') {
            rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${ORG_USERNAME} --jwtkeyfile ${JWT_KEY_LOCATION} --instanceurl ${SFDC_HOST}"
            if (rc != 0) { error 'hub org authorization failed' }
            rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:config:set defaultdevhubusername=${ORG_USERNAME}"
        }

        stage('Create Package Version') {
            output = sh returnStdout: true, script: "${toolbelt}/sfdx force:package:version:create --package \"Nebula Logger - Plugin - Email\" -d force-app --installationkeybypass --wait 10 --json --targetdevhubusername ${ORG_USERNAME}"
            sleep 300
            def jsonSlurper = new JsonSlurperClassic()
            def response = jsonSlurper.parseText(output)
            PACKAGE_VERSION = response.result.SubscriberPackageVersionId
            response = null
        }
        
        if (!isDevHub) {
            stage('Create Scratch Org') {
                rmsg = sh returnStdout: true, script: "${toolbelt}/sfdx force:org:create --definitionfile config/project-scratch-def.json -d 1 --json --setdefaultusername"
                printf rmsg
                def jsonSlurper = new JsonSlurperClassic()
                def robj = jsonSlurper.parseText(rmsg)
                if (robj.status != 0) { error 'org creation failed: ' + robj.message }
                SFDC_USERNAME=robj.result.username
                robj = null
            }
        }

        stage('Instal Dependencies') {
            def filePath = "$env.WORKSPACE/sfdx-project.json"
            def inputFile = new File(filePath)
            def data = new JsonSlurperClassic().parseText(readFile(filePath))
            def packages = data.packageDirectories.dependencies.flatten()          
            packages.each { entry -> 
                entry.each { k, v ->
                    rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:package:install -p $v -r --noprompt --targetusername ${isDevHub ? ORG_USERNAME : SFDC_USERNAME} --wait 5"
                    if (rc != 0 ) {
                        deletePackageVersion(toolbelt, PACKAGE_VERSION)
                        if (!isDevHub) {
                            deleteScratchOrg(toolbelt, SFDC_USERNAME)
                        }
                        error 'cannot install dependencies'
                    }
                }
            }
        }

        stage('Install Package Version') {
            rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:package:install --package ${PACKAGE_VERSION} -r --noprompt --targetusername ${isDevHub ? ORG_USERNAME : SFDC_USERNAME} --wait 5"
            if (rc != 0) {
                deletePackageVersion(toolbelt, PACKAGE_VERSION)
                if (!isDevHub) {
                    deleteScratchOrg(toolbelt, SFDC_USERNAME)
                }
                error 'Install Package version failed'
            }
        }

        stage('Run Apex Tests') {
                sh "mkdir -p ${RUN_ARTIFACT_DIR}"
                timeout(time: 1000, unit: 'SECONDS') {
                rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:apex:test:run --testlevel RunLocalTests --wait 10 --outputdir ${RUN_ARTIFACT_DIR} --resultformat tap --targetusername ${isDevHub ? ORG_USERNAME : SFDC_USERNAME}"
                if (rc != 0) {
                    error 'apex test run failed'
                    deletePackageVersion(toolbelt, PACKAGE_VERSION)
                    if (!isDevHub) {
                        deleteScratchOrg(toolbelt, SFDC_USERNAME) 
                    }            
                }
            }
        }

        if (!isDevHub) {
            stage('Delete Package Version') {
               deletePackageVersion(toolbelt, PACKAGE_VERSION) 
            }
            stage('Delete Test Org') {
                deleteScratchOrg(toolbelt, SFDC_USERNAME) 
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

void deletePackageVersion(toolbelt, packageVersion) {
    timeout(time: 120, unit: 'SECONDS') {
        rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:package:delete --p ${packageVersion} --noprompt"
        if (rc != 0) {
            error 'package version deletion request failed'
        }
    }
}
