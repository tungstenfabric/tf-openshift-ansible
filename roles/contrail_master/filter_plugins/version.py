import re

class FilterModule(object):

    def filters(self):
        return {
            'get_contrail_version': self.get_contrail_version,
        }

    def get_contrail_version(self, tag):
        """
        Function returns contrail version from image-tag in comparable format.
        Returned value is integer looks like 500 (for 5.0 version) or 2002 for 2002 version
        If container tag is 'latest' or if the version cannot be evaluated then 
        version will be set to 9999
        If someone changes the naming conventions, he must make changes in this function to support these new conventions.
        """
        for release in [r"21\d\d", r"20\d\d", r"19\d\d"]:
            tag_date = re.findall(release, tag)
            if len(tag_date) != 0:
                return int(tag_date[0])

        if '5.1' in tag:
            return 510
        elif '5.0' in tag:
            return 500

        # master/latest version
        return 9999
