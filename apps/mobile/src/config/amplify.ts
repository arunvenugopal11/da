import { Amplify } from 'aws-amplify';

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: 'ap-southeast-1_XXXXXXXXX',    // TODO: replace with SSM /{env}/infrastructure/cognito/user-pool-id
      userPoolClientId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX', // TODO: replace with SSM /{env}/infrastructure/cognito/mobile-client-id
      signUpVerificationMethod: 'code',
      loginWith: {
        phone: true,
      },
    },
  },
});
