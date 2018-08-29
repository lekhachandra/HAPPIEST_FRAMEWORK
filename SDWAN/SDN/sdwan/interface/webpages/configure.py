from SDN.sdwan.interface.webpages.base import BasePage
import time


class Configure(BasePage):

    SECTION_NAME = 'Configure'
    LINK_OPTION_XPATH = "//select[@id='{0}']"
    ACTION_BUTTON_XPATH = "//button[@id='{0}_button']"


    def navigate_to_configure_section(self):

        if self.navigate_to_section(name = Configure.SECTION_NAME):
            print("Navigate to Configuration Page")

    def configure_service(self, service, link_type):

        elem = self.gui_driver.driver.find_element_by_xpath(self.LINK_OPTION_XPATH.format(service))
        link_options = elem.find_elements_by_tag_name("option")
        time.sleep(3)
        for option in link_options:
            if option.get_attribute("value") == link_type:
                time.sleep(3)
                option.click()
                elem = self.gui_driver.driver.find_element_by_xpath(self.ACTION_BUTTON_XPATH.format(service))
                elem.click()

class SERVICE_TYPE(object):

    SSH = 'ssh'
    ARP = 'arp'


class LINK_TYPE(object):

    MPLS = 'MPLS'
    DIA = 'DIA'
    DROP = 'DROP'
    EDGE = 'EDGE'

    PORT_MAPPING = {MPLS:2,
                    DIA:3,
                    EDGE:1}
