import { GraphQLClient, gql } from 'graphql-request'

const hygraphClient = new GraphQLClient(import.meta.env.HYGRAPH_ENDPOINT)

interface JobRole {
	jobTitle: string
	companyName: string
	skill: string[]
	yearsOfService: string
}

interface CvData {
	name: string
	jobRoles: JobRole | JobRole[]
}

interface CvResponse {
	cvs: CvData[]
}

const CV_QUERY = gql`
	query {
		cvs {
			name
			jobRoles {
				... on JobRole {
					jobTitle
					companyName
					skill
					yearsOfService
				}
			}
		}
	}
`

export async function fetchCvData(): Promise<CvData[]> {
	const { cvs } = await hygraphClient.request<CvResponse>(CV_QUERY)
	return cvs
}
