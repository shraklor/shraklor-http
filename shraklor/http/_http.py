'''
Author: Shraklor

Target: Python3.6
'''

import logging
import json
from requests import Session, Request
# pylint: disable=import-error
from requests.packages.urllib3 import disable_warnings
# pylint: disable=import-error
from requests.packages.urllib3.exceptions import InsecureRequestWarning


class Http():
    '''
    Class to help with making HTTP calls
    '''

    _ALLOWED_METHODS = {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'}
    _DEFAULT_HEADER = {'Content-Type':'application/json', 'Accept':'application/json'}
    _DEFAULT_TIMEOUT = 30
    _DEFAULT_PROXY = dict()
    LOG_FORMAT = '%(asctime)-15s [%(levelname)-8s] %(module)-32s %(message)s'

    def __init__(self, **kwargs):
        '''
        init method
        '''
        self.logger = logging.getLogger(__name__)
        logging.basicConfig(format=self.LOG_FORMAT)
        self.logger.setLevel(logging.WARNING)
        #self.logger.setLevel(logging.DEBUG)

        # used to not display warning on site certificates
        self.ignore_security_warning = True

        self.header = kwargs.get('header', self._DEFAULT_HEADER)
        self.proxy = kwargs.get('proxy', self._DEFAULT_PROXY)
        self.timeout = kwargs.get('timeout', self._DEFAULT_TIMEOUT)
        self.stream = kwargs.get('stream', False)


    @staticmethod
    def call(method, url, data=None, **kwargs):
        '''
        static method that lets you do whatever
        '''
        return Http()._call(method, url, data, **kwargs)


    def send(self, method, url, data=None, **kwargs):
        '''
        method that lets you do whatever
        '''
        return self._call(method, url, data, **kwargs)


    def _call(self, method, url, data=None, **kwargs):
        '''
        method that does all the actual work
        '''
        method = method.upper()

        if method not in self._ALLOWED_METHODS:
            raise ValueError('Unsupported HTTP method "{0}"'.format(method))

        self.logger.info('HTTP {0} {1}'.format(method, url))

        if self.ignore_security_warning is True:
            disable_warnings(InsecureRequestWarning)

        header = kwargs.get('header', getattr(self, 'header', self.header))
        proxy = kwargs.get('proxy', getattr(self, 'proxy', self.proxy))
        timeout = kwargs.get('timeout', getattr(self, 'timeout', self.timeout))
        stream = kwargs.get('stream', getattr(self, 'stream', self.stream))

        self.logger.debug('Http._call[\'header\'] => {0}'.format(header))

        if proxy:
            self.logger.debug('Http._call[\'proxy\'] => {0}'.format(proxy))

        if timeout != self._DEFAULT_TIMEOUT:
            self.logger.debug('Http._call[\'timeout\'] => {0}'.format(timeout))

        if stream:
            self.logger.debug('Http._call[\'stream\'] => {0}'.format(stream))

        #self.logger.debug('Http._call[\'data\'] => {0}'.format(data))

        if data is not None and isinstance(data, str) is False:
            data = json.dumps(data)

        with Session() as sess:
            request = Request(method=method,
                              url=url,
                              data=data,
                              headers=header)
            package = request.prepare()
            response = sess.send(package,
                                stream=stream,
                                verify=False,
                                proxies=proxy,
                                timeout=timeout)

            response.raise_for_status()

        return response


    def get(self, url):
        '''
        HTTP GET method that calls self._call
        '''
        return self._call('GET', url, data=None)


    def post(self, url, data):
        '''
        HTTP POST method that calls self._call
        '''
        return self._call('POST', url, data=data)


    def put(self, url, data):
        '''
        HTTP PUT method that calls self._call
        '''
        return self._call('PUT', url, data=data)


    def patch(self, url, data):
        '''
        HTTP PUT method that calls self._call
        '''
        return self._call('PUT', url, data=data)


    def option(self, url):
        '''
        HTTP PUT method that calls self._call
        '''
        return self._call('PUT', url, data=None)


    def delete(self, url):
        '''
        HTTP DELETE method that calls self._call
        '''
        return self._call('DELETE', url, data=None)
