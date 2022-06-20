/**
 * Created by szlat@softserveinc.com on 05/08/2022.
 * @description Utils class for emails.
 */
public class EmailLoggerUtils {
    /**
     * @description Loads org-wide email address by developer name.
     * @param  emailAddressName Org-Wide email address' developer name
     * @return org-wide default email address            
     */
    public static OrgWideEmailAddress getOrgWideEmailAddress(String emailAddressName) {
        OrgWideEmailAddress orgWideEmailAddress = null;
        if (String.isNotBlank(emailAddressName)) {
            if (Test.isRunningTest()) {
                orgWideEmailAddress = getMockOrgWideEmailAddress(emailAddressName);
            } else {
                orgWideEmailAddress = queryOrgWideEmailAddress(emailAddressName);
            }
        }
        return orgWideEmailAddress;
    }

    private static OrgWideEmailAddress queryOrgWideEmailAddress(String emailAddressName) {
        OrgWideEmailAddress [] orgWideEmailAddresses = [SELECT Id FROM OrgWideEmailAddress
                                                            WHERE DisplayName = :emailAddressName LIMIT 1];
        return (orgWideEmailAddresses.isEmpty()) ? null : orgWideEmailAddresses[0];
    }

    private static OrgWideEmailAddress getMockOrgWideEmailAddress(String emailAddressName) {
        return new OrgWideEmailAddress(
            Address = 'no@reply.com',
            DisplayName = emailAddressName,
            IsAllowAllProfiles = true
        );
    }
}