import React, { useState } from 'react'
import { useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'

import { Input as AntInput, Form, message, Checkbox } from 'antd'
import type { FormProps } from 'antd'

import { useAuth } from '@/context/authContext'
import useNavigation from '@/hooks/Navigation/useNavigation'
import { Button, Input } from '@/components/common'
import PageMeta from '@/components/ui/PageMeta/PageMeta'
import DividedPage from '@/components/layout/DividedPage/DividedPage'
import PageTitle from '@/components/ui/PageText/Title'
import { register } from '@/services/api/Authentification/AuthApi'

import { UserRegisterPayload } from '@/interfaces/User/User'

import backgroundImg from '@/assets/images/building.jpg'
import '@/App.css'
import style from './Register.module.css'

const Register: React.FC = () => {
  const { goToLogin, goToSuccessRegisterTenant, goToOverview } = useNavigation()
  const { login } = useAuth()
  const [form] = Form.useForm()
  const { leaseId } = useParams()
  const [loading, setLoading] = useState(false)

  const { t } = useTranslation()

  const onFinish: FormProps<UserRegisterPayload>['onFinish'] = async values => {
    try {
      setLoading(true)
      const { password, confirmPassword } = values
      if (password === confirmPassword) {
        const userInfo = {
          ...values,
          leaseId
        }

        try {
          await register(userInfo)

          const loginValues = {
            username: values.email,
            password: values.password,
            grant_type: 'password'
          }

          try {
            await login(loginValues, leaseId)
            message.success(t('pages.register.register_success'))
            form.resetFields()

            if (leaseId) {
              goToSuccessRegisterTenant()
            } else {
              goToOverview()
            }
          } catch (loginError: any) {
            console.error('Login after registration failed:', loginError)
            message.warning(
              t('pages.register.register_success_but_login_failed')
            )
            goToLogin()
          }
        } catch (registerError: any) {
          if (registerError.response?.status === 409) {
            message.error(t('pages.register.email_already_used'))
          } else {
            message.error(t('pages.register.register_error'))
          }
          console.error('Registration error:', registerError)
        }
      } else {
        message.error(t('pages.register.confirm_password_error'))
      }
    } catch (err: any) {
      console.error('Unexpected error:', err)
      message.error(t('pages.register.unexpected_error'))
    } finally {
      setLoading(false)
    }
  }

  const onFinishFailed: FormProps<UserRegisterPayload>['onFinishFailed'] =
    () => {
      message.error(t('pages.register.fill_fields'))
    }

  return (
    <>
      <PageMeta
        title={t('pages.register.document_title')}
        description={t('pages.register.document_description')}
        keywords="sign up, authentication, Keyz"
      />
      <DividedPage
        childrenLeft={
          <img
            src={backgroundImg}
            alt="background"
            className={style.backgroundImg}
          />
        }
        childrenRight={
          <>
            <PageTitle title={t('pages.register.title')} size="title" />
            <PageTitle
              title={t('pages.register.description')}
              size="subtitle"
            />
            <Form
              form={form}
              name="basic"
              initialValues={{ termAgree: false }}
              onFinish={onFinish}
              onFinishFailed={onFinishFailed}
              autoComplete="off"
              layout="vertical"
              style={{ width: '90%', maxWidth: '400px' }}
            >
              <Form.Item
                label={t('components.input.first_name.label')}
                name="firstname"
                rules={[
                  {
                    required: true,
                    message: t('components.input.first_name.error'),
                    pattern: /^[A-Za-zÀ-ÿ]+([ '-][A-Za-zÀ-ÿ]+)*$/
                  }
                ]}
              >
                <Input
                  className="input"
                  size="middle"
                  placeholder={t('components.input.first_name.placeholder')}
                  aria-label={t('components.input.first_name.placeholder')}
                />
              </Form.Item>

              <Form.Item
                label={t('components.input.last_name.label')}
                name="lastname"
                rules={[
                  {
                    required: true,
                    message: t('components.input.last_name.error'),
                    pattern: /^[A-Za-zÀ-ÿ]+([ '-][A-Za-zÀ-ÿ]+)*$/
                  }
                ]}
              >
                <Input
                  className="input"
                  size="middle"
                  placeholder={t('components.input.last_name.placeholder')}
                  aria-label={t('components.input.last_name.placeholder')}
                />
              </Form.Item>

              <Form.Item
                label={t('components.input.email.label')}
                name="email"
                rules={[
                  {
                    required: true,
                    message: t('components.input.email.error'),
                    type: 'email'
                  }
                ]}
              >
                <Input
                  className="input"
                  size="middle"
                  placeholder={t('components.input.email.placeholder')}
                  aria-label={t('components.input.email.placeholder')}
                />
              </Form.Item>

              <Form.Item
                label={t('components.input.password.label')}
                name="password"
                rules={[
                  {
                    required: true,
                    message: t('components.input.password.error')
                  }
                ]}
              >
                <AntInput.Password
                  className="input"
                  size="middle"
                  placeholder={t('components.input.password.placeholder')}
                  aria-label={t('components.input.password.placeholder')}
                />
              </Form.Item>

              <Form.Item
                label={t('components.input.confirm_password.label')}
                name="confirmPassword"
                rules={[
                  {
                    required: true,
                    message: t('components.input.confirm_password.error')
                  }
                ]}
              >
                <AntInput.Password
                  className="input"
                  size="middle"
                  placeholder={t(
                    'components.input.confirm_password.placeholder'
                  )}
                  aria-label={t(
                    'components.input.confirm_password.placeholder'
                  )}
                />
              </Form.Item>
              <Form.Item name="termAgree" valuePropName="checked">
                <div className={style.optionsContainer}>
                  <Checkbox>{t('pages.register.agree_terms')}</Checkbox>
                </div>
              </Form.Item>
              <Form.Item>
                <Button
                  className="submitButton"
                  htmlType="submit"
                  size="large"
                  color="default"
                  variant="solid"
                  loading={loading}
                >
                  {t('components.button.sign_up')}
                </Button>
              </Form.Item>

              <div
                className={style.dontHaveAccountContainer}
                style={{ display: leaseId ? 'none' : 'flex' }}
              >
                <span className={style.footerText}>
                  {t('pages.register.already_have_account')}
                </span>
                <span
                  className={style.footerLink}
                  onClick={goToLogin}
                  role="link"
                  tabIndex={0}
                  onKeyDown={e => {
                    if (e.key === 'Enter') goToLogin()
                  }}
                >
                  {t('components.button.sign_in')}
                </span>
              </div>
            </Form>
          </>
        }
      />
    </>
  )
}

export default Register
