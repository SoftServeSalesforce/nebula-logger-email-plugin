/**
 * Created by szlat@softserveinc.com on 05/08/2022.
 * @description Utils class for emails.
 */
public class EmailUtils {
    /**
     * @description Loads org-wide email address by developer name.
     * @param  orgWideName Org-Wide email address' developer name
     * @return org-wide default email address            
     */
    public static OrgWideEmailAddress getOrgWideEmailAddress(String orgWideName) {
        OrgWideEmailAddress orgWide;
        if (Test.isRunningTest()) {
            orgWide = new OrgWideEmailAddress(
                    Address = 'no@reply.com',
                    DisplayName = TestUtils.ORG_WIDE_EMAIL_NAME,
                    IsAllowAllProfiles = true
                );
        }

        if (String.isNotBlank(orgWideName)) {
            List<OrgWideEmailAddress> addresses = [SELECT Id 
                                                    FROM OrgWideEmailAddress
                                                    WHERE DisplayName = :orgWideName LIMIT 1];
            if (!addresses.isEmpty()) {
                orgWide = addresses[0];
            }
        }
        return orgWide;
    }
}